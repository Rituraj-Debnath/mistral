#!/usr/bin/env python3
import os
import argparse
import sys
import shutil
from huggingface_hub import hf_hub_download

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repo", required=True, help="Hugging Face repo id (e.g. TheBloke/...)")
    p.add_argument("--filename", required=True, help="Filename in the repo (the .gguf)")
    p.add_argument("--out", required=True, help="Directory to place the downloaded file")
    args = p.parse_args()

    token = os.getenv("HF_TOKEN")
    if not token:
        print("HF_TOKEN env var not set", file=sys.stderr)
        sys.exit(2)

    os.makedirs(args.out, exist_ok=True)

    print(f"Downloading {args.filename} from {args.repo} ...")
    # hf_hub_download returns path in local cache; copy to out dir so Ollama can use it
    local_path = hf_hub_download(repo_id=args.repo, filename=args.filename, repo_type="model", token=token)
    dest = os.path.join(args.out, os.path.basename(local_path))
    shutil.copy(local_path, dest)
    print(f"Saved to {dest}")

if __name__ == "__main__":
    main()