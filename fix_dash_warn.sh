#!/bin/bash
# fix_dash_warn.sh - two small fixes to files installed today. Run as ansible on ansible-forge.
#   1. play_weekly_molecule.sh: the "image built in the last 24 h" window becomes IMG_MAX_AGE_MIN
#      (default 1440, unchanged), so a manual run later in the week can test that week's images:
#        IMG_MAX_AGE_MIN=10080 /opt/ansible/nucleus/playbooks/play_weekly_molecule.sh
#   2. both deployment roles' nucleus-images.yml: search only the signature folders that exist
#      (provenance/signatures, and provenance/<class> for releases before FY27 Q2), which removes
#      the "is not a directory" warning.
# Backups next to each file as <file>.bak-<date>. Safe to run twice.
set -euo pipefail
[ "$(id -un)" = ansible ] || { echo "run this as ansible"; exit 1; }
R=/opt/ansible/nucleus
python3 - "$R" <<'PY'
import sys, shutil, time
R = sys.argv[1]; stamp = time.strftime('%Y%m%d-%H%M')
def edit(path, pairs):
    s = open(path).read(); new = s
    for old, rep in pairs:
        if rep in new: continue                      # already done
        assert new.count(old) == 1, '%s: expected text not found once - nothing changed' % path
        new = new.replace(old, rep)
    if new == s: print('unchanged (already fixed): ' + path); return
    shutil.copy2(path, path + '.bak-' + stamp); open(path, 'w').write(new); print('fixed: ' + path)

edit(R + '/playbooks/play_weekly_molecule.sh', [
  ('MIN_FREE_GB="${MIN_FREE_GB:-50}"                 # don\'t start a test with less free than this\n',
   'MIN_FREE_GB="${MIN_FREE_GB:-50}"                 # don\'t start a test with less free than this\n'
   'IMG_MAX_AGE_MIN="${IMG_MAX_AGE_MIN:-1440}"       # test only images built this recently (minutes); raise it for a manual run later in the week\n'),
  ('fresh() { # fresh <weekly dir> <class>-<component> - a tarball built in the last 24 h exists\n'
   '  [ -n "$(find "$1" -mindepth 3 -maxdepth 3 -path "*/images/$2-*.tar.gz" -mmin -1440 2>/dev/null)" ]',
   'fresh() { # fresh <weekly dir> <class>-<component> - a tarball built in the last IMG_MAX_AGE_MIN minutes exists\n'
   '  [ -n "$(find "$1" -mindepth 3 -maxdepth 3 -path "*/images/$2-*.tar.gz" -mmin -"$IMG_MAX_AGE_MIN" 2>/dev/null)" ]'),
])
edit(R + '/roles/configure_guacamole/tasks/nucleus-images.yml', [
  ('''    paths:
      - "{{ avocado_artifact_dir }}/provenance/signatures"
      - "{{ avocado_artifact_dir }}/provenance/{{ guac_image_class }}"''',
   '''    paths: "{{ [avocado_artifact_dir ~ '/provenance/signatures', avocado_artifact_dir ~ '/provenance/' ~ guac_image_class] | select('directory') | list }}"'''),
  ('# releases built before that (FY27 Q1) deploy unchanged.\n- name: Find nucleus signature files',
   '# releases built before that (FY27 Q1) deploy unchanged. Only folders that exist are searched.\n- name: Find nucleus signature files'),
])
edit(R + '/roles/configure_grafana_stack/tasks/nucleus-images.yml', [
  ('''    paths:
      - "{{ grafana_stack_artifact_dir }}/provenance/signatures"
      - "{{ grafana_stack_artifact_dir }}/provenance/nucleus"''',
   '''    paths: "{{ [grafana_stack_artifact_dir ~ '/provenance/signatures', grafana_stack_artifact_dir ~ '/provenance/nucleus'] | select('directory') | list }}"'''),
  ('# releases built before that (FY27 Q1) deploy unchanged.\n- name: Find nucleus signature files',
   '# releases built before that (FY27 Q1) deploy unchanged. Only folders that exist are searched.\n- name: Find nucleus signature files'),
])
PY
