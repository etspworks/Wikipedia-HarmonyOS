// svc_edit — the wikitext behind the section editor and the article description editor.
//
// The port had no editor at all: both pencil actions opened the remote ?action=edit page in
// SinglePageWebViewController, which renders the VisualEditor bootstrap ("The editor will now
// load...") — a JavaScript shell that never loads in a natively-rendered document, and a
// malformed URL there answered "This page could not be loaded." The editor screens now talk
// to the action API directly, the way SectionEditorViewController and
// DescriptionEditViewController do in the source.
import { HttpClient } from './HttpClient';
import { AuthService, TokenType, mediaWikiApiURL } from './AuthService';

interface ParseSectionJson {
  index?: string;
  anchor?: string;
  line?: string;
}

interface ParseJson {
  sections?: ParseSectionJson[];
}

interface ParseResponseJson {
  parse?: ParseJson;
}

interface RevisionSlotJson {
  content?: string;
}

interface RevisionSlotsJson {
  main?: RevisionSlotJson;
}

interface RevisionJson {
  slots?: RevisionSlotsJson;
}

interface PageJson {
  revisions?: RevisionJson[];
  pageprops?: Record<string, string>;
}

interface QueryJson {
  pages?: PageJson[];
}

interface QueryResponseJson {
  query?: QueryJson;
}

interface ErrorJson {
  code?: string;
  info?: string;
}

interface EditResultJson {
  result?: string;
  newrevid?: number;
}

interface EditResponseJson {
  edit?: EditResultJson;
  error?: ErrorJson;
}

interface WbEntityJson {
  id?: string;
}

interface WbSetDescriptionResponseJson {
  success?: number;
  entity?: WbEntityJson;
  error?: ErrorJson;
}

interface VisualEditorMetadataJson {
  notices?: Record<string, string>;
}

interface VisualEditorResponseJson {
  visualeditor?: VisualEditorMetadataJson;
}

export class EditService {
  // action=parse&prop=sections maps the anchor the rendered document carries onto the
  // section number the edit API needs. The lead section is 0 and has no heading to match.
  static async sectionIndexForAnchor(host: string, title: string, anchor: string): Promise<number> {
    if (anchor === '') {
      return 0;
    }
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), {
      'action': 'parse',
      'page': title,
      'prop': 'sections',
      'format': 'json',
      'formatversion': '2'
    });
    const resp: ParseResponseJson = await HttpClient.getJson<ParseResponseJson>(url);
    const sections: ParseSectionJson[] = resp.parse?.sections ?? [];
    for (const s of sections) {
      if ((s.anchor ?? '') === anchor) {
        return Number.parseInt(s.index ?? '0', 10);
      }
    }
    // An anchor the API does not know (a heading this port slugified itself) edits the lead
    // rather than silently editing the wrong section.
    return 0;
  }

  // action=query&prop=revisions&rvsection=N — the wikitext of one section.
  // EditNoticesFetcher.fetchNotices: action=visualeditor&paction=metadata, the notices whose
  // key contains "editnotice", as HTML
  static async fetchEditNotices(host: string, title: string): Promise<string[]> {
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), {
      'action': 'visualeditor',
      'paction': 'metadata',
      'page': title,
      'errorsuselocal': '1',
      'formatversion': '2',
      'format': 'json'
    });
    const resp: VisualEditorResponseJson = await HttpClient.getJson<VisualEditorResponseJson>(url);
    const notices: Record<string, string> = resp.visualeditor?.notices ?? {};
    return Object.keys(notices).filter((key: string) => key.indexOf('editnotice') >= 0)
      .map((key: string) => notices[key]);
  }

  static async fetchSectionWikitext(host: string, title: string, section: number): Promise<string> {
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), {
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'content',
      'rvslots': 'main',
      'rvsection': section.toString(),
      'rvlimit': '1',
      'titles': title,
      'format': 'json',
      'formatversion': '2'
    });
    const resp: QueryResponseJson = await HttpClient.getJson<QueryResponseJson>(url);
    const pages: PageJson[] = resp.query?.pages ?? [];
    if (pages.length === 0) {
      throw new Error('no such page: ' + title);
    }
    const revisions: RevisionJson[] = pages[0].revisions ?? [];
    if (revisions.length === 0) {
      throw new Error('no revision for: ' + title);
    }
    return revisions[0].slots?.main?.content ?? '';
  }

  // action=edit with the csrf token. Anonymous edits are what the API answers to when no
  // session cookie is set; its refusal is surfaced verbatim rather than swallowed.
  // Returns the new revision id (edit.newrevid). The image-recommendation flow passes its own
  // tags (app-suggestededit, app-image-add-top) and the Save changes toggles.
  static async publishSection(host: string, title: string, section: number,
    wikitext: string, summary: string, tags: string = 'app-section-edit', minor: boolean = false,
    watch: boolean = false): Promise<number> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'edit',
      'title': title,
      'section': section.toString(),
      'text': wikitext,
      'summary': summary,
      'tags': tags,                                // WMFEditTag.appSectionSource by default
      'format': 'json',
      'formatversion': '2',
      'token': token
    };
    if (minor) {
      form['minor'] = '1';
    }
    if (watch) {
      form['watchlist'] = 'watch';
    }
    const text: string = await HttpClient.postForm(mediaWikiApiURL(host), form);
    const root: EditResponseJson = HttpClient.parseJson<EditResponseJson>(text);
    const info: string = root.error?.info ?? '';
    if (info !== '') {
      throw new Error(info);
    }
    if ((root.edit?.result ?? '') !== 'Success') {
      throw new Error(text);
    }
    return root.edit?.newrevid ?? 0;
  }

  // The Wikidata item behind an article — the description editor writes there, exactly as
  // the source's WikidataFetcher does for every wiki that has no local short description.
  static async wikidataItemID(host: string, title: string): Promise<string> {
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), {
      'action': 'query',
      'prop': 'pageprops',
      'ppprop': 'wikibase_item',
      'titles': title,
      'format': 'json',
      'formatversion': '2'
    });
    const resp: QueryResponseJson = await HttpClient.getJson<QueryResponseJson>(url);
    const pages: PageJson[] = resp.query?.pages ?? [];
    if (pages.length === 0) {
      return '';
    }
    const props: Record<string, string> | undefined = pages[0].pageprops;
    return props === undefined ? '' : (props['wikibase_item'] ?? '');
  }

  // wbsetdescription on www.wikidata.org (WikidataFetcher.swift).
  static async publishDescription(languageCode: string, itemID: string,
    description: string): Promise<void> {
    if (itemID === '') {
      throw new Error('This article has no Wikidata item to describe.');
    }
    const wikidataHost: string = 'www.wikidata.org';
    const token: string = await AuthService.fetchToken(wikidataHost, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'wbsetdescription',
      'id': itemID,
      'language': languageCode,
      'value': description,
      'tags': 'app-description-add',               // WMFEditTag.appDescriptionAdd
      'format': 'json',
      'formatversion': '2',
      'token': token
    };
    const text: string = await HttpClient.postForm(mediaWikiApiURL(wikidataHost), form);
    const root: WbSetDescriptionResponseJson =
      HttpClient.parseJson<WbSetDescriptionResponseJson>(text);
    const info: string = root.error?.info ?? '';
    if (info !== '') {
      throw new Error(info);
    }
    if ((root.success ?? 0) !== 1) {
      throw new Error(text);
    }
  }
}
