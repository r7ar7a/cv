# Requirements:

Docker installed

# Usage:
From repo root:
```
docker build -t cv .

results="$HOME/data/cv"  # or whatever
cfg=cfg/rara.yaml

mkdir -p "$results"

docker run -it --user="$(id -u):$(id -g)" -v "$PWD:/cv" -v "$results:/cv/bin/pdf" cv "$cfg"
```
