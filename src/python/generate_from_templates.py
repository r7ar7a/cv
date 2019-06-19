import yaml
from copy import deepcopy
from jinja2 import Environment, FileSystemLoader, StrictUndefined
import sys
import os

def select_lang(cfg, n):
  if isinstance(cfg, dict):
    get_iterator = cfg.items
  elif isinstance(cfg, list):
    get_iterator = lambda: enumerate(cfg)
  else:
    return
  replacements = []
  for k, v in get_iterator():
    if isinstance(v, dict) and 'i18n' in v:
      if 'value' in v:
        new_val = {v['i18n'][n]: v['value']}
      else:
        new_val = v['i18n'][n]
      replacements.append((k, new_val))
  for replacement in replacements:
    cfg[replacement[0]] = replacement[1]
  for _, v in get_iterator():
    select_lang(v, n)

def main():
  from_dir, to_dir, cfg_file = sys.argv[1:]
  env = Environment(loader = FileSystemLoader(from_dir), undefined=StrictUndefined)


  with open(cfg_file, 'r') as f:
    orig_cfg = yaml.load(f)

  for postfix, version in orig_cfg['versions'].items():
    cfg = deepcopy(orig_cfg)
    lang_index = cfg['langs'].index(version['lang'])
    select_lang(cfg, lang_index)
    cfg['pc'] = version['pc']
    import pprint
    pprint.pprint(cfg)

    try:
      os.makedirs(os.path.join(to_dir, 'tex'))
    except FileExistsError as e:
      pass  # We only want to ensure that it exists

    generated = env.get_template(os.path.join('tex', 'cv.tex')).render(**cfg)
    with open(os.path.join(to_dir, 'tex', 'cv_{}.tex'.format(postfix)), 'w') as f:
      f.write(generated)

    


main()


