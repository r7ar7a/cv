# Requirements:

Docker installed

# Usage:
From repo root:
```
docker build -t cv .

mkdir -p bin/pdf
results="$HOME/data/cv"  # or whatever
cfg=cfg/rara.yaml

mkdir -p "$results"

docker run --rm -it --user="$(id -u):$(id -g)" -v "$PWD:/cv" -v "$results:/cv/bin/pdf" cv "$cfg"
```
