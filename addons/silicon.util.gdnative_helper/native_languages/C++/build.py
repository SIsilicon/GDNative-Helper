#!/usr/bin/env python
import os, sys, shutil, subprocess, multiprocessing
from pathlib import Path

build_file = Path(sys.argv[0])
library_path = Path(sys.argv[1])
library_extension = sys.argv[2]

platform = sys.argv[3]
arch = sys.argv[4]
target = sys.argv[5]

bits = "32" if arch in ("32", "x86", "armv7") else "64"
cmd_break = "&" if os.name == "nt" else ";"


def run_commands(cwd, args):
	print(subprocess.check_output(args, shell=(os.name == "nt"), text=True, cwd=cwd))


def unzip_url(url, dir, from_name, to_name):
	from io import BytesIO
	from urllib.request import urlopen
	from zipfile import ZipFile
	with urlopen(url) as zipresp:
		with ZipFile(BytesIO(zipresp.read())) as zfile:
			zfile.extractall(str(dir))
			if os.path.exists(dir / to_name):
				os.removedirs(str(dir / to_name))
			os.rename(str(dir / from_name), str(dir / to_name))


data_dir = (build_file / "../../..").resolve()
bindings_path = data_dir / "godot-cpp"

# Download godot cpp bindings if they are not where they need to be.
if not bindings_path.exists():
	try:
		unzip_url("https://github.com/godotengine/godot-cpp/archive/master.zip", data_dir, "godot-cpp-master", "godot-cpp")
		unzip_url("https://github.com/godotengine/godot_headers/archive/master.zip", data_dir / "godot-cpp", "godot_headers-master", "godot_headers")
	except:
		e = sys.exc_info()[0]
		raise RuntimeError("%s: Failed to download cpp-bindings!" % e.strerror)

if platform == "ios" and arch == "arm64v8":
	arch = "arm64"

# Get Android NDK path
android_ndk_root = ""
if platform == "android":
	import json

	get_ndk = False
	config_file = build_file.parent / "config.json"
	config_data = {}

	if config_file.exists():
		with open(config_file, 'r') as config:
			data = json.load(config)
			if data != None and "android_ndk_root" in data:
				android_ndk_root = data["android_ndk_root"]
			else:
				get_ndk = True
			config_data = data if data != None else {}
	else:
		get_ndk = True

	if get_ndk:
		import tkinter as tk
		from tkinter import filedialog

		root = tk.Tk()
		root.withdraw()

		android_ndk_root = filedialog.askdirectory()

		config_data["android_ndk_root"] = android_ndk_root
		with open(config_file, 'w') as config:
			json.dump(config_data, config)

# Build godot bindings if there is none.

static_extension = {
	"windows": "lib",
	"linux": "a",
	"macos": "a",
	"android": "a",
	"ios": "a"
}

bindings_file = Path(bindings_path, "bin/libgodot-cpp.%s.%s.%s.%s" % (
	platform,
	target,
	arch,
	static_extension[platform]
))

if not bindings_file.exists():
	print("Generating binding library...")
	run_commands(str(bindings_path), [
		"scons",
			"platform=" + platform,
			"bits=" + bits,
			("android_arch=" + arch) if platform == "android" else "",
			("ios_arch=" + arch) if platform == "ios" else "",
			("ANDROID_NDK_ROOT=" + android_ndk_root) if platform == "android" else "",
			"generate_bindings=yes",
			"target=" + target,
			"-j%s" % multiprocessing.cpu_count()
	])

library_name = library_path.name
binary_path = library_path / "bin"

target_file_path = binary_path / ("lib-%s.%s.%s.%s" % (library_name, platform, target, arch))

# Create directory for library files to reside
temp_file = str(binary_path)
try:
	os.makedirs(temp_file)
except: pass
temp_file += "/lib-%s.%s.%s.%s" % (library_name, platform, target, arch)

# Get older dll out of the way.
lib_name = "%s.%s" % (temp_file, library_extension)
try:
	if os.path.exists(lib_name) and platform == "windows" and os.name == "nt":
		# if os.path.exists(lib_name + ".old"):
		# 	os.remove(lib_name + ".old")
		os.replace(lib_name, lib_name + ".old")
except OSError as e:
	raise OSError("%s: %s" % (e.strerror, lib_name))

# First we'll copy the SConstruct to the source code.
shutil.copyfile(
	data_dir / "native_languages/C++/SConstruct",
	library_path / "../SConstruct"
)

# Build source code
print("Building source")
run_commands(str(library_path / ".."), [
	"scons",
		"platform=" + platform,
		"bits=" + bits,
		"target=" + target,
		("android_arch=" + arch) if platform == "android" else "",
		("ios_arch=" + arch) if platform == "ios" else "",
		("ANDROID_NDK_ROOT=" + android_ndk_root) if platform == "android" else "",
		"cpp_bindings_path=" + ("%s/" % bindings_path),
		"source_path=" + str(library_path / "src"),
		"target_path=" + str(library_path / "bin") + "/",
		"target_name=" + str(target_file_path.name),
		"-j%s" % multiprocessing.cpu_count()
])

# Remove SConstruct once we're done.
os.remove(library_path / "../SConstruct")
