"""Repository-wide checks: the rules that are about the repository, not about one tweak.

`check.py` is written against one tweak at a time. These are the rules that were, until now,
paragraphs in CLAUDE.md -- and a rule that lives only in prose gets broken by whoever did not read
it. Each one is here because that exact mistake happened:

  1. **No `+N` version in anything committed.** `1.76.0+1` is a local-build suffix; committed to
     main it becomes the version CI reads and the publish step refuses it -- a red run for a build
     never meant to leave the machine.
  2. **A changelog's newest entry is the control file's version**, for every tweak and the suite.
     Release notes and the Sileo depiction are generated from the changelog, so a mismatch ships a
     page describing a different release.
  3. **README badges, the README table and CLAUDE.md "Known state" carry the control version.**
     CLAUDE.md says a stale state line is believed first, because that file is read first.
  4. **The suite is bumped whenever a tweak that is in it is.** `buildsuite.yml` finds the suite's
     own version already tagged and prints "already released -- building, not releasing": compiled,
     thrown away, a green run, no update offered. (Local only: compares the git index with HEAD, and
     CI's shallow clone has no HEAD to compare with.)
  5. **`.no-suite` and `buildsuite.yml` agree.** A tweak taken out of the suite needs the marker and
     a `!tweaks/<name>/**` line in the workflow's `paths:`; Spotify once left with the first two
     only and a later suite release failed after compiling everything.
  6. **Every workflow that publishes takes the `albrhi-pages` concurrency group** -- the one thing
     stopping two runs writing `gh-pages` at once.
  7. **A step id named in an `if:` exists.** A condition naming a step that does not exist is
     silently false; two store-copy steps were skipped for exactly that after being pasted between
     workflows.

Run on its own (`python3 tools/check-repo.py`) or through `tools/check.py`, which calls it first.
Each rule was proved by reintroducing its bug (see CLAUDE.md, *Source checks*).
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

problems = []


def report(msg):
    problems.append(msg)


def git(*args):
    try:
        return subprocess.run(['git'] + list(args), capture_output=True, text=True, check=True).stdout
    except Exception:
        return None


IN_CI = bool(os.environ.get('GITHUB_ACTIONS'))


def tree_text(path):
    try:
        return open(path, encoding='utf-8').read()
    except OSError:
        return None


def staged_text(path):
    """What `git commit` would take: the index. Only for the one rule that is about what gets
    committed -- a local build's temporary `+N` sits in the tree and is none of its business."""
    return git('show', ':' + path)


def control_version(text):
    m = re.search(r'^Version:\s*(\S+)', text or '', re.M)
    return m.group(1) if m else None


# name used in README / CLAUDE.md -> directory holding its control file
PRODUCTS = {
    'Albrhi': 'suite', 'Instagram': 'tweaks/instagram', 'YouTube': 'tweaks/youtube',
    'X': 'tweaks/twitter', 'TikTok': 'tweaks/tiktok', 'YouTube Music': 'tweaks/ytmusic',
    'Panel': 'tweaks/panel', 'Spotify': 'tweaks/spotify', 'NextUp': 'tweaks/nextup',
    'Watch': 'tweaks/watch',
}

versions = {}
for name, directory in PRODUCTS.items():
    version = control_version(tree_text(directory + '/control'))
    if not version:
        report('%s/control has no Version: line' % directory)
        continue
    versions[name] = version
    # 1. In CI the tree is what is committed; elsewhere the index is, so a local build's `+N`
    #    passes until somebody stages it.
    to_commit = control_version(tree_text(directory + '/control') if IN_CI
                                else staged_text(directory + '/control'))
    if to_commit and '+' in to_commit:
        report('%s/control is at %s — a "+N" suffix is a local-build number and must never be '
               'committed (CI reads it as the version and the publish step refuses it). Edit the '
               'value back by hand; never `git checkout -- <file>`.' % (directory, to_commit))

# 2. a changelog's newest entry is the control version
for name, directory in PRODUCTS.items():
    path = directory + '/CHANGELOG.md'
    if name not in versions or not os.path.isfile(path):
        continue
    top = None
    for line in open(path, encoding='utf-8'):
        m = re.match(r'##\s+v?(\d[^\s]*)', line)
        if m:
            top = m.group(1)
            break
    if top != versions[name].split('+')[0]:
        report('%s: newest entry is %s but %s/control says %s — release notes and the depiction '
               'are generated from the changelog' % (path, top, directory, versions[name]))

# 3. README badges, README table, CLAUDE.md state line
readme = open('README.md', encoding='utf-8').read() if os.path.isfile('README.md') else ''
BADGE = {'Albrhi': 'Albrhi', 'Instagram': 'Instagram', 'YouTube': 'YouTube', 'X': 'X',
         'TikTok': 'TikTok', 'YouTube Music': 'YT%20Music', 'Spotify': 'Spotify', 'Panel': 'Panel',
         'NextUp': 'NextUp', 'Watch': 'Watch'}
for name, badge in BADGE.items():
    if name not in versions:
        continue
    m = re.search(r'img\.shields\.io/badge/%s-([0-9][^-]*)-' % re.escape(badge), readme)
    if not m:
        report('README.md has no badge for %s' % name)
    elif m.group(1) != versions[name].split('+')[0]:
        report('README.md badge says %s %s but the control file says %s' % (name, m.group(1), versions[name]))

for name in ('Instagram', 'YouTube', 'X', 'TikTok', 'YouTube Music', 'Panel', 'Spotify', 'NextUp', 'Watch'):
    if name not in versions:
        continue
    m = re.search(r'^\|\s*\*\*\[%s\]\([^)]*\)\*\*\s*\|[^|]*\|\s*([0-9][^\s|]*)\s*\|' % re.escape(name),
                  readme, re.M)
    if not m:
        report('README.md table has no row for %s' % name)
    elif m.group(1) != versions[name].split('+')[0]:
        report('README.md table says %s %s but the control file says %s' % (name, m.group(1), versions[name]))

claude = open('CLAUDE.md', encoding='utf-8').read() if os.path.isfile('CLAUDE.md') else ''
state = re.search(r'\*\*Versions\*\*.*?suite \*\*[^*]+\*\*', claude, re.S)
if not state:
    report('CLAUDE.md has no "Versions" line in Known state')
else:
    line = state.group(0)
    for name in ('Instagram', 'YouTube', 'X', 'TikTok', 'YouTube Music', 'Panel', 'Spotify', 'NextUp', 'Watch'):
        if name not in versions:
            continue
        m = re.search(r'(?<![A-Za-z])%s \*\*([0-9][^*]*)\*\*' % re.escape(name), line)
        if not m:
            report('CLAUDE.md "Versions" line does not name %s' % name)
        elif m.group(1) != versions[name].split('+')[0]:
            report('CLAUDE.md "Versions" line says %s %s but the control file says %s — a stale state '
                   'line is believed first' % (name, m.group(1), versions[name]))
    m = re.search(r'suite \*\*([^*]+)\*\*', line)
    if m and 'Albrhi' in versions and m.group(1) != versions['Albrhi'].split('+')[0]:
        report('CLAUDE.md "Versions" line says suite %s but suite/control says %s' % (m.group(1), versions['Albrhi']))

# 4. the suite moves when a tweak in it does (local only)
if not IN_CI and git('rev-parse', '--verify', 'HEAD') is not None:
    def head_version(path):
        out = git('show', 'HEAD:' + path)
        return control_version(out) if out is not None else None

    moved = []
    for name, directory in PRODUCTS.items():
        if name == 'Albrhi' or name not in versions:
            continue
        if os.path.exists(directory + '/.no-suite'):
            continue
        before = head_version(directory + '/control')
        if before and before.split('+')[0] != versions[name].split('+')[0]:
            moved.append('%s %s → %s' % (name, before, versions[name]))
    suite_before = head_version('suite/control')
    if moved and suite_before and 'Albrhi' in versions \
            and suite_before.split('+')[0] == versions['Albrhi'].split('+')[0]:
        report('%s changed but suite/control is still %s — buildsuite.yml would find v%s already '
               'tagged and build without releasing (a green run and no update offered)'
               % (', '.join(moved), suite_before, suite_before))

# 5. .no-suite and buildsuite.yml agree
workflow = open('.github/workflows/buildsuite.yml', encoding='utf-8').read() \
    if os.path.isfile('.github/workflows/buildsuite.yml') else ''
live_workflow = '\n'.join(l for l in workflow.splitlines() if not l.lstrip().startswith('#'))
for control in sorted(glob.glob('tweaks/*/control')):
    directory = os.path.dirname(control)
    excluded = ("'!%s/**'" % directory) in live_workflow or ('"!%s/**"' % directory) in live_workflow \
        or ('!%s/**' % directory) in live_workflow
    marked = os.path.exists(directory + '/.no-suite')
    if marked and not excluded:
        report('%s has a .no-suite marker but buildsuite.yml\'s paths: has no !%s/** line — a push '
               'touching only it would start a suite run with nothing to do' % (directory, directory))
    if excluded and not marked:
        report('buildsuite.yml excludes !%s/** but %s has no .no-suite marker' % (directory, directory))

# 6 and 7. workflows
for path in sorted(glob.glob('.github/workflows/*.yml')):
    text = open(path, encoding='utf-8').read()
    live = '\n'.join(l for l in text.splitlines() if not l.lstrip().startswith('#'))

    publishes = 'action-gh-release' in live or re.search(r'git push[^\n]*gh-pages', live) \
        or re.search(r'branch:\s*gh-pages', live)
    if publishes and 'group: albrhi-pages' not in live:
        report('%s publishes but does not take the albrhi-pages concurrency group — two runs could '
               'write gh-pages at once' % path)

    ids = set(re.findall(r'^\s*(?:-\s*)?id:\s*([A-Za-z0-9_-]+)', live, re.M))
    for n, line in enumerate(live.splitlines(), 1):
        for step_id in re.findall(r'\bsteps\.([A-Za-z0-9_-]+)\.', line):
            if step_id not in ids:
                report('%s names steps.%s but no step in the file has that id — a condition naming a '
                       'step that does not exist is silently false (%s)' % (path, step_id, line.strip()[:80]))

if problems:
    for p in problems:
        print('FAIL  ' + p)
    sys.exit(1)

print('repository checks clean (%d products, versions read from %s)'
      % (len(versions), 'the tree'))
