import os, sys, json
from pathlib import Path

sys.path.append(sys.argv[1])

from build import execute

with open("addons/silicon.util.gdnative_helper/build_config.json", 'r') as config:
    args = json.load(config)
    args["library_name"] = sys.argv[2]
    args["target_file_path"] = sys.argv[3]
    args["source_path"] = sys.argv[4]
    args["library_extension"] = sys.argv[5]
    args["platform"] = sys.argv[6]
    args["arch"] = sys.argv[7]
    args["target"] = sys.argv[8]
    args["gd_settings_dir"] = str(Path(sys.argv[1], "../..").resolve())

    os.chdir(sys.argv[1])
    execute(args)
