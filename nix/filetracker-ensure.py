#!/usr/bin/env python3
from os import environ, readlink
from pathlib import Path
import string
from time import sleep
from filetracker.utils import file_digest
from filetracker.client import Client, FiletrackerError

envs_not_found = []

def require_env(name: str):
    if name in environ:
        return environ[name]
    else:
        envs_not_found.append(name)
        return ""

def finish_env():
    if len(envs_not_found) > 0:
        print(f"This script requires the following environment variables to be set")
        for env in envs_not_found:
            print(f"- {env}")
        exit(1)

def is_sha256_hash(text: str) -> bool:
    HASH_ALPHABET = string.digits + string.ascii_lowercase

    if len(text) != 64:
        return False

    for chr in text:
        if chr not in HASH_ALPHABET:
            return False

    return True

remote_name = require_env("REMOTE_PATH")
source_path = Path(require_env("SOURCE_PATH"))
filetracker_media_root = Path(require_env("FILETRACKER_MEDIA_ROOT"))
# Used by filetracker.client.Client
require_env("FILETRACKER_URL")

finish_env()

upload = False

link_path = filetracker_media_root / "links" / remote_name.lstrip('/')

if not link_path.exists():
    upload = True
else:
    # Python 3.8 does not support Path.readlink (introduced in 3.9)
    # link_target = link_path.readlink()
    link_target = Path(readlink(link_path))

    print(f"{remote_name} -> {link_path} -> {link_target}")

    remote_hash = link_target.name
    local_hash = file_digest(source_path.open('rb'))

    assert is_sha256_hash(remote_hash)
    assert is_sha256_hash(local_hash)

    print(f"remote hash: {remote_hash}")
    print(f"local hash: {local_hash}")

    upload = remote_hash != local_hash

if upload:
    print("Uploading file to filetracker")
    tries = 0
    while True:
        try:
            Client().put_file(remote_name, str(source_path), to_local_store=False)
            break
        except FiletrackerError as error:
            print(f"Failed to upload file to filetracker: {error}")
            tries += 1

            if tries < 3:
                print("Retrying in 3 seconds...")
                sleep(3)
            else:
                raise error
else:
    print("Skipping file upload")
