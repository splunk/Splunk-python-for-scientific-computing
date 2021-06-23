# Python for Scientific Computing (PSC)

The Python for Scientific Computing app is an app that bundles Miniconda (a
commercial binary distribution of Python) and some common Python libraries
for scientific computing: numpy, scipy, pandas, scikit-learn, statsmodels.

This repo builds PSC for 3 platforms:

* Mac: <https://splunkbase.splunk.com/app/2881/>
* Linux 64-bit: <https://splunkbase.splunk.com/app/2882/>
* Windows 64-bit: <https://splunkbase.splunk.com/app/2883/>

## Building your own Python for Scientific Computing

1. Update `packages.txt` in the repo root dir
    * Always specify your `python` version, keep major version consistent with
      the target splunk platform. e.g. Splunk 8.0.x ships with python 3.7.x,
      so put `python==3.7.*` in there or the specific version you need
    * Fix the major version, leave the minor version flexible, i.e. `pandas==0.25.*`
    * There's another `packages.txt` inside of each platform's folder, which act
      as the lock file to lockdown the specific versions of all dependencies
      (like `pip freeze`).
2. Run freeze task of the build scripts
    * There are two build scripts to be used on different platforms
        * `repack.sh` for Linux and OSX
        * `repack.ps1` for Windows
    * run `bash repack.sh freeze`
3. If there's any package _*ADDED*_ to existing `packages.txt`, we can run
   `bash repack.sh analyze` to inspect the package dependency tree
4. Optional, check licenses, *if you are redistributing this app*, you need
   to include the proper licenses of the package redistributed, run
   `bash repack.sh license` to generate a license file
    * Note you may need to update `license_db.csv` if you included a new package
5. Finally, when the platform specific `packages.txt` looks good, run
   `bash repack.sh build` to build the Python for Scientific Computing app
6. Copy it to your `$SPLUNK_HOME/etc/apps` folder
    * Note, due to the size of this app, installing it via web
      installer/deployer may fail with a timeout error


## Releasing a new version of Python for Scientific Computing
If you are releasing a new PSC, you need follow these steps before running the repack scripts: 
1. Edit the value of `VERSION` variable at the top of the repack scripts.
2. Set the values of `MINICONDA_VERSION`, `LINUX_MD5`, and `OSX_MD5` variables to the appropriate value. Note that for OSX we use the `.sh` installer and not the `.pkg` installer. For the list of available miniconda versions, their respective package names, and MD5 hash, see https://repo.anaconda.com/miniconda/.
3. Update the README file under `package` directory with the correct version of included packages.
