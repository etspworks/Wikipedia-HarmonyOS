// Ported from Wikipedia/Code/MWKImageInfo.h/.m and MWKLicense.h (Commons imageinfo/extmetadata).

export class MWKLicense {
  code: string | null = null;
  shortDescription: string | null = null;
  url: string | null = null;
}

interface ExtMetadataValueJson {
  value?: string;
}

interface ExtMetadataJson {
  ImageDescription?: ExtMetadataValueJson;
  LicenseShortName?: ExtMetadataValueJson;
  License?: ExtMetadataValueJson;
  LicenseUrl?: ExtMetadataValueJson;
  Artist?: ExtMetadataValueJson;
}

export interface MWKImageInfoJson {
  canonicaltitle?: string;
  url?: string;
  descriptionurl?: string;
  thumburl?: string;
  width?: number;
  height?: number;
  thumbwidth?: number;
  thumbheight?: number;
  extmetadata?: ExtMetadataJson;
}

export class MWKImageInfo {
  canonicalPageTitle: string | null = null;        // JSON: canonicaltitle
  canonicalFileURL: string | null = null;          // JSON: url
  imageDescription: string | null = null;          // JSON: extmetadata.ImageDescription.value
  imageDescriptionIsRTL: boolean = false;
  license: MWKLicense | null = null;               // JSON: extmetadata License* fields
  filePageURL: string | null = null;               // JSON: descriptionurl
  imageThumbURL: string | null = null;             // JSON: thumburl
  imageWidth: number = 0;                          // JSON: width
  imageHeight: number = 0;                         // JSON: height
  thumbWidth: number = 0;                          // JSON: thumbwidth
  thumbHeight: number = 0;                         // JSON: thumbheight
  owner: string | null = null;                     // JSON: extmetadata.Artist.value

  static fromJson(j: MWKImageInfoJson): MWKImageInfo {
    const out = new MWKImageInfo();
    out.canonicalPageTitle = j.canonicaltitle ?? null;
    out.canonicalFileURL = j.url ?? null;
    out.filePageURL = j.descriptionurl ?? null;
    out.imageThumbURL = j.thumburl ?? null;
    out.imageWidth = j.width ?? 0;
    out.imageHeight = j.height ?? 0;
    out.thumbWidth = j.thumbwidth ?? 0;
    out.thumbHeight = j.thumbheight ?? 0;
    const meta = j.extmetadata;
    if (meta !== undefined) {
      out.imageDescription = meta.ImageDescription?.value ?? null;
      out.owner = meta.Artist?.value ?? null;
      const license = new MWKLicense();
      license.code = meta.License?.value ?? null;
      license.shortDescription = meta.LicenseShortName?.value ?? null;
      license.url = meta.LicenseUrl?.value ?? null;
      out.license = license;
    }
    return out;
  }
}
