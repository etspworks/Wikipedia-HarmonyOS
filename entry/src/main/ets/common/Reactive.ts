// port_rxswift — Rule 11 reactive port.
// Audit result (codegraph + grep over the 2026.08.11 source): the app imports RxSwift NOWHERE
// (0 files); its reactive layer is Combine — @Published/CurrentValueSubject/PassthroughSubject
// with the operators actually used: sink (37), merge (11), debounce (6), receive(on) (3),
// removeDuplicates (2). Only those primitives are ported; receive(on) is a no-op here because
// ArkTS callbacks already run on the event loop.

export type Observer<T> = (value: T) => void;

export class Subscription {
  private readonly onDispose: () => void;
  private disposed: boolean = false;

  constructor(onDispose: () => void) {
    this.onDispose = onDispose;
  }

  // Combine: AnyCancellable.cancel()
  dispose(): void {
    if (!this.disposed) {
      this.disposed = true;
      this.onDispose();
    }
  }
}

// Combine: PassthroughSubject — emits to current subscribers, keeps no value.
export class Subject<T> {
  private observers: Observer<T>[] = [];

  // Combine: sink
  subscribe(observer: Observer<T>): Subscription {
    this.observers.push(observer);
    return new Subscription((): void => {
      const index: number = this.observers.indexOf(observer);
      if (index >= 0) {
        this.observers.splice(index, 1);
      }
    });
  }

  // Combine: send
  next(value: T): void {
    const snapshot: Observer<T>[] = this.observers.slice(0);
    for (const observer of snapshot) {
      observer(value);
    }
  }
}

// Combine: CurrentValueSubject / @Published — replays the current value on subscribe.
export class BehaviorSubject<T> extends Subject<T> {
  private currentValue: T;

  constructor(initialValue: T) {
    super();
    this.currentValue = initialValue;
  }

  get value(): T {
    return this.currentValue;
  }

  next(value: T): void {
    this.currentValue = value;
    super.next(value);
  }

  subscribe(observer: Observer<T>): Subscription {
    const subscription: Subscription = super.subscribe(observer);
    observer(this.currentValue);
    return subscription;
  }
}

// Combine: .debounce(for:scheduler:) — trailing-edge debounce.
export function debounce<T>(source: Subject<T>, milliseconds: number, observer: Observer<T>): Subscription {
  let timer: number = -1;
  const inner: Subscription = source.subscribe((value: T): void => {
    if (timer >= 0) {
      clearTimeout(timer);
    }
    timer = setTimeout((): void => {
      timer = -1;
      observer(value);
    }, milliseconds);
  });
  return new Subscription((): void => {
    if (timer >= 0) {
      clearTimeout(timer);
      timer = -1;
    }
    inner.dispose();
  });
}

// Combine: .removeDuplicates() — strict-equality comparison, as the source uses it on value types.
export function removeDuplicates<T>(source: Subject<T>, observer: Observer<T>): Subscription {
  let hasLast: boolean = false;
  let last: T | null = null;
  return source.subscribe((value: T): void => {
    if (hasLast && last === value) {
      return;
    }
    hasLast = true;
    last = value;
    observer(value);
  });
}

// Combine: Publishers.Merge — one subscription over several sources.
export function merge<T>(sources: Subject<T>[], observer: Observer<T>): Subscription {
  const inner: Subscription[] = [];
  for (const source of sources) {
    inner.push(source.subscribe(observer));
  }
  return new Subscription((): void => {
    for (const subscription of inner) {
      subscription.dispose();
    }
  });
}
