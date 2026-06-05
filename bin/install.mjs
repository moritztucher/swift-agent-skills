#!/usr/bin/env node
// Full-setup installer for swift-agent-skills.
// Copies skills, agents, docs, hooks, and example settings into ~/.claude/,
// backing up anything already there. Mirrors the manual block in the README.
//
//   npx swift-agent-skills                  (once published to npm)
//   npx github:moritztucher/swift-agent-skills   (runs straight from the repo)
//
// Flags:
//   --dry-run   show what would happen, change nothing
//   --yes / -y  skip the confirmation prompt
//   --help / -h show this help

import { cpSync, existsSync, mkdirSync, renameSync, chmodSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline";

const argv = new Set(process.argv.slice(2));
const DRY = argv.has("--dry-run");
const YES = argv.has("--yes") || argv.has("-y");

if (argv.has("--help") || argv.has("-h")) {
  console.log(
    [
      "swift-agent-skills — full setup installer",
      "",
      "Copies skills, agents, docs, hooks, and example settings into ~/.claude/.",
      "Existing skills/agents/docs/hooks directories are backed up first.",
      "CLAUDE.md and settings.json are only written if they don't already exist.",
      "",
      "Usage: npx swift-agent-skills [--dry-run] [--yes]",
    ].join("\n"),
  );
  process.exit(0);
}

const PKG_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const CLAUDE = join(homedir(), ".claude");

// Dim/colour helpers — fall back to plain text when not a TTY.
const c = process.stdout.isTTY
  ? { dim: (s) => `\x1b[2m${s}\x1b[0m`, bold: (s) => `\x1b[1m${s}\x1b[0m`, green: (s) => `\x1b[32m${s}\x1b[0m`, yellow: (s) => `\x1b[33m${s}\x1b[0m` }
  : { dim: (s) => s, bold: (s) => s, green: (s) => s, yellow: (s) => s };

const log = (...a) => console.log(...a);

// Pick a backup path that doesn't already exist (<name>.backup, .backup.1, ...).
function backupPathFor(target) {
  let candidate = `${target}.backup`;
  let n = 1;
  while (existsSync(candidate)) candidate = `${target}.backup.${n++}`;
  return candidate;
}

// Back up an existing dir, then copy the bundled one in.
function installDir(name) {
  const src = join(PKG_ROOT, name);
  const dest = join(CLAUDE, name);
  if (!existsSync(src)) {
    log(c.yellow(`  ! skip ${name} — not found in package`));
    return;
  }
  if (existsSync(dest)) {
    const backup = backupPathFor(dest);
    log(c.dim(`  ↩ backing up ${name} → ${backup.replace(homedir(), "~")}`));
    if (!DRY) renameSync(dest, backup);
  }
  log(c.green(`  ✓ ${name}/`));
  if (!DRY) cpSync(src, dest, { recursive: true });
}

// Copy a single file only if the destination is absent (never clobber user config).
function installFileIfAbsent(srcRel, destRel) {
  const src = join(PKG_ROOT, srcRel);
  const dest = join(CLAUDE, destRel);
  if (!existsSync(src)) return;
  if (existsSync(dest)) {
    log(c.dim(`  • keep existing ${destRel}`));
    return;
  }
  log(c.green(`  ✓ ${destRel}`));
  if (!DRY) cpSync(src, dest);
}

function chmodExec(...paths) {
  for (const p of paths) {
    if (!existsSync(p)) continue;
    if (statSync(p).isDirectory()) {
      for (const f of readdirSync(p)) if (f.endsWith(".sh")) chmodExec(join(p, f));
    } else if (!DRY) {
      chmodSync(p, 0o755);
    }
  }
}

function confirm(question) {
  if (YES || !process.stdin.isTTY) return Promise.resolve(true);
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(/^y(es)?$/i.test(answer.trim()));
    });
  });
}

async function main() {
  log(c.bold("\nswift-agent-skills — full setup"));
  log(c.dim(`  source: ${PKG_ROOT}`));
  log(c.dim(`  target: ${CLAUDE.replace(homedir(), "~")}`));
  if (DRY) log(c.yellow("  (dry run — nothing will be written)\n"));
  else log("");

  const ok = await confirm(
    `This will copy skills, agents, docs, hooks and example settings into ${c.bold("~/.claude/")},\nbacking up any existing skills/agents/docs/hooks directories first.\nProceed? ${c.dim("[y/N] ")}`,
  );
  if (!ok) {
    log("Aborted.");
    process.exit(1);
  }
  log("");

  if (!DRY) mkdirSync(CLAUDE, { recursive: true });

  for (const dir of ["skills", "agents", "docs", "hooks"]) installDir(dir);

  installFileIfAbsent("CLAUDE.md", "CLAUDE.md");
  installFileIfAbsent("settings/settings.json.example", "settings.json");
  installFileIfAbsent("statusline-command.sh", "statusline-command.sh");

  chmodExec(join(CLAUDE, "hooks"), join(CLAUDE, "statusline-command.sh"));

  log(c.bold(c.green("\nDone.")));
  log("Next steps:");
  log(`  • Opt a project into the iOS guide — add this as the first line of its CLAUDE.md:`);
  log(c.dim(`      @~/.claude/docs/ios/ios-guide.md`));
  log(`  • Or run ${c.bold("/ios-init")} in a project to scaffold it automatically.`);
  log(`  • Review ${c.dim("~/.claude/settings.json")} — it enables specific hooks and the statusline.\n`);
}

main().catch((err) => {
  console.error(c.yellow("\nInstall failed:"), err?.message ?? err);
  process.exit(1);
});
