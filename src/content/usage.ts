/**
 * 内容 by page (S33 WP33.2; the owner, 2026-10-31: 「缺乏当前内容与页面绑定 … 以页面为基础展开所有当前页面用到的resource
 * … 最终目的就是要明白自己改动的地方到底改在哪里」): where each of the app's texts and images shows, read from the app's
 * own Dart code, so the map follows the code by itself.
 *
 * The code is cut into its top-level declarations (classes, functions, variables; the members of an extension on
 * AppLocalizations each on their own), each with what it uses: texts (`l10n.<key>`, or a key named bare inside such
 * an extension), images (`ContentScope.imageOf(context, '<key>')`) and the declarations it names. From each page (a
 * `…Page` class, and the app around them) everything it reaches is walked, stopping at other pages: a text shows on
 * every page that reaches it, by each way it is reached. The parts on the way take their names from pages.ts.
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { PAGES, partName } from "./pages.js";

/** Where a resource shows: a page, and the named parts on the way to it. */
export interface Place {
  page: string;
  parts: string[];
}

/** A top-level declaration of the app's code and what it uses. */
interface Decl {
  id: string;
  name: string;
  file: string;
  keys: Set<string>;
  images: Set<string>;
  rich: Set<string>;
  refs: Set<string>;
}

export interface Usage {
  /** By resource: a text's key, or `image:<key>`. Empty for one no page reaches. */
  places: Map<string, Place[]>;
  /** The texts the app shows through ContentText: those that may hold HTML (WP33.4). */
  rich: Set<string>;
}

const APP_LIB = fileURLToPath(new URL("../../app/lib/", import.meta.url));

/** The app's own Dart files, by their path under lib/: not what is generated. */
export function appSources(root = APP_LIB): { file: string; source: string }[] {
  const out: { file: string; source: string }[] = [];
  const walk = (dir: string) => {
    for (const name of readdirSync(dir).sort()) {
      const path = join(dir, name);
      if (statSync(path).isDirectory()) {
        const rel = relative(root, path).replaceAll("\\", "/");
        if (rel !== "generated" && rel !== "l10n/gen") walk(path);
      } else if (name.endsWith(".dart")) {
        out.push({
          file: relative(root, path).replaceAll("\\", "/"),
          source: readFileSync(path, "utf8"),
        });
      }
    }
  };
  walk(root);
  return out;
}

/** [src] without its comments (`//`, `///`, `/* … *\/`, nested); strings kept, so a `//` inside one stays. */
export function stripComments(src: string): string {
  type Frame = { kind: "code"; depth: number } | { kind: "str"; quote: string; raw: boolean };
  const stack: Frame[] = [{ kind: "code", depth: 0 }];
  let out = "";
  let i = 0;
  while (i < src.length) {
    const top = stack[stack.length - 1]!;
    const c = src[i]!;
    if (top.kind === "code") {
      if (src.startsWith("//", i)) {
        while (i < src.length && src[i] !== "\n") i++;
        continue;
      }
      if (src.startsWith("/*", i)) {
        let depth = 0;
        do {
          if (src.startsWith("/*", i)) {
            depth++;
            i += 2;
          } else if (src.startsWith("*/", i)) {
            depth--;
            i += 2;
          } else {
            if (src[i] === "\n") out += "\n";
            i++;
          }
        } while (depth > 0 && i < src.length);
        continue;
      }
      const raw = c === "r" && /['"]/.test(src[i + 1] ?? "") && !/[\w$]/.test(src[i - 1] ?? "");
      const at = raw ? i + 1 : i;
      const q = src[at];
      if (q === "'" || q === '"') {
        const quote = src.startsWith(q.repeat(3), at) ? q.repeat(3) : q;
        out += src.slice(i, at + quote.length);
        i = at + quote.length;
        stack.push({ kind: "str", quote, raw });
        continue;
      }
      if (c === "{") top.depth++;
      else if (c === "}") {
        // The end of a string's ${…}: back into the string.
        if (top.depth === 0 && stack.length > 1) {
          stack.pop();
          out += c;
          i++;
          continue;
        }
        top.depth--;
      }
      out += c;
      i++;
      continue;
    }
    if (!top.raw && c === "\\") {
      out += src.slice(i, i + 2);
      i += 2;
    } else if (src.startsWith(top.quote, i)) {
      out += top.quote;
      i += top.quote.length;
      stack.pop();
    } else if (!top.raw && src.startsWith("${", i)) {
      out += "${";
      i += 2;
      stack.push({ kind: "code", depth: 0 });
    } else {
      out += c;
      i++;
    }
  }
  return out;
}

const ID = String.raw`[A-Za-z_$][\w$]*`;
/** A top-level declaration's first line, its name in group 1. */
const DECLARATIONS = [
  new RegExp(String.raw`^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*class\s+(${ID})`),
  new RegExp(String.raw`^(?:mixin|enum|typedef)\s+(${ID})`),
  new RegExp(String.raw`^extension\s+type\s+(${ID})`),
  new RegExp(String.raw`^extension\s+(${ID})\s+on\b`),
  new RegExp(String.raw`^(?:final|const|var|late)\s+(?:[\w$<>?,. ]+\s+)?(${ID})\s*=`),
  new RegExp(String.raw`^[\w$<>?,. ]*?\bget\s+(${ID})`),
  // A function: the shortest return type that fits (it may be a record, `List<(String, String)>`).
  new RegExp(String.raw`^(?:[\w$<>?,.\[\]() ]+?\s+)?(${ID})\s*(?:<[^>]*>)?\s*\(`),
];
/** A member of an extension: a method or a getter, two spaces in. */
const MEMBER = new RegExp(
  String.raw`^  (?:[\w$<>?,. ]+\s+)?(?:get\s+)?(${ID})\s*(?:<[^>]*>)?\s*(?:\(|=>|\{)`,
);

const declName = (line: string) => {
  for (const re of DECLARATIONS) {
    const m = re.exec(line);
    if (m) return m[1];
  }
  return undefined;
};

/** A file's declarations: each starts on a line at its left edge, and runs to the next. */
export function declarationsOf(source: string): { name: string; code: string; on?: string }[] {
  const out: { name: string; lines: string[]; on?: string }[] = [];
  for (const line of stripComments(source).split("\n")) {
    const top = /^[A-Za-z_$]/.test(line) && !/^(?:import|export|part|library)\b/.test(line);
    const name = top ? declName(line) : undefined;
    if (name) {
      const on = /^extension\s+\S+\s+on\s+(\w+)/.exec(line)?.[1];
      out.push({ name, lines: [line], ...(on && { on }) });
    } else {
      out.at(-1)?.lines.push(line);
    }
  }
  // An extension on AppLocalizations: each member on its own, named as it is called (`l10n.<member>`).
  return out.flatMap((d) => {
    if (d.on !== "AppLocalizations") return [{ name: d.name, code: d.lines.join("\n") }];
    const members: { name: string; code: string[] }[] = [];
    for (const line of d.lines.slice(1)) {
      const m = MEMBER.exec(line);
      if (m) members.push({ name: `.${m[1]}`, code: [line] });
      else members.at(-1)?.code.push(line);
    }
    return members.map((m) => ({ name: m.name, code: m.code.join("\n"), on: "AppLocalizations" }));
  });
}

/**
 * Where every text ([keys]) and image shows in the app's code ([sources]): from each of [pages], by the parts [name]
 * names (pages.ts's).
 */
export function usageOf(
  sources: { file: string; source: string }[],
  keys: ReadonlySet<string>,
  name: (code: string, file: string) => string | undefined = partName,
  pages: Readonly<Record<string, string>> = PAGES,
): Usage {
  const decls: Decl[] = [];
  const codes = new Map<string, string>();
  for (const { file, source } of sources) {
    for (const d of declarationsOf(source)) {
      const id = `${file}#${d.name}`;
      codes.set(id, d.code);
      decls.push({
        id,
        name: d.name,
        file,
        keys: new Set(),
        images: new Set(),
        rich: new Set(),
        refs: new Set(),
      });
      // Inside an extension on AppLocalizations a text is named bare.
      if (d.on)
        for (const w of d.code.match(/[A-Za-z_$][\w$]*/g) ?? [])
          if (keys.has(w)) decls.at(-1)!.keys.add(w);
    }
  }
  const byName = new Map<string, Decl[]>();
  for (const d of decls) byName.set(d.name, [...(byName.get(d.name) ?? []), d]);

  for (const d of decls) {
    const code = codes.get(d.id)!;
    // What holds the texts: l10n, and anything typed or made AppLocalizations here.
    const holders = new Set(["l10n"]);
    for (const m of code.matchAll(/\bAppLocalizations\??\s+([A-Za-z_$][\w$]*)/g))
      holders.add(m[1]!);
    for (const m of code.matchAll(/([A-Za-z_$][\w$]*)\s*=\s*AppLocalizations\.of\(/g))
      holders.add(m[1]!);
    const uses = [
      ...code.matchAll(/\b([A-Za-z_$][\w$]*)\.([A-Za-z_$][\w$]*)/g),
      ...[...code.matchAll(/AppLocalizations\.of\([^)]*\)\.([A-Za-z_$][\w$]*)/g)].map((m) => [
        m[0],
        "l10n",
        m[1],
      ]),
    ];
    for (const [, holder, name] of uses) {
      if (!holders.has(holder!)) continue;
      if (keys.has(name!)) d.keys.add(name!);
      for (const member of byName.get(`.${name}`) ?? []) d.refs.add(member.id);
    }
    for (const m of code.matchAll(/ContentScope\.imageOf\(\s*\w+\s*,\s*'(\w+)'/g))
      d.images.add(m[1]!);
    for (const m of code.matchAll(/ContentText\([^;]*?contentKey:\s*'(\w+)'/g)) d.rich.add(m[1]!);
    for (const w of new Set(code.match(/[A-Za-z_$][\w$]*/g))) {
      if (w === d.name) continue;
      for (const other of byName.get(w) ?? []) {
        // A private name is its own file's.
        if (w.startsWith("_") && other.file !== d.file) continue;
        d.refs.add(other.id);
      }
    }
  }

  const byId = new Map(decls.map((d) => [d.id, d]));
  const isPage = (d: Decl) => d.name in pages;
  const places = new Map<string, Place[]>();
  const place = (resource: string, p: Place) => {
    const list = places.get(resource) ?? [];
    if (!list.some((q) => q.page === p.page && q.parts.join() === p.parts.join())) list.push(p);
    places.set(resource, list);
  };
  for (const root of decls.filter(isPage)) {
    // Breadth first: each declaration by the shortest way from the page, other pages left to themselves.
    const way = new Map<string, string[]>([[root.id, []]]);
    const queue = [root];
    while (queue.length) {
      const d = queue.shift()!;
      const parts = way.get(d.id)!;
      for (const k of d.keys) place(k, { page: root.name, parts });
      for (const k of d.images) place(`image:${k}`, { page: root.name, parts });
      for (const ref of d.refs) {
        const next = byId.get(ref)!;
        if (way.has(next.id) || isPage(next)) continue;
        const part = name(next.name, next.file);
        way.set(next.id, part && part !== parts.at(-1) ? [...parts, part] : parts);
        queue.push(next);
      }
    }
  }
  for (const k of keys) if (!places.has(k)) places.set(k, []);
  const rich = new Set(decls.flatMap((d) => [...d.rich]));
  return { places, rich };
}

let cached: Usage | undefined;

/** The app's own map (its code doesn't change while the server runs). */
export function appUsage(keys: ReadonlySet<string>): Usage {
  return (cached ??= usageOf(appSources(), keys));
}
