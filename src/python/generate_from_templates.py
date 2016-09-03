import yaml
from jinja2 import Environment, FileSystemLoader
import sys
import os

def main():
  from_dir, to_dir, cfg_file = sys.argv[1:]
  env = Environment(loader = FileSystemLoader(from_dir))


  with open(cfg_file, 'r') as f:
    cfg = yaml.load(f)
  print(cfg)


  try:
    os.makedirs(os.path.join(to_dir, 'tex'))
  except FileExistsError as e:
    pass  # We only want to ensure that it exists

  generated = env.get_template(os.path.join('tex', 'cv.tex')).render(pc=False, **cfg)
  with open(os.path.join(to_dir, 'tex', 'cv_npc.tex'), 'w') as f:
    f.write(generated)

    


main()


