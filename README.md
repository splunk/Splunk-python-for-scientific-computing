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
2. Run freeze task of the build scripts for each platform and push the updated versions of platform/packages.txt to the repo.
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
5. Update the requirements.txt's content with the linux_x86_64/packages.txt for prodsec-review scans.
6. Finally, when the platform specific `packages.txt` looks good, run
   `bash repack.sh build` to build the Python for Scientific Computing app
7. Copy it to your `$SPLUNK_HOME/etc/apps` folder
    * Note, due to the size of this app, installing it via web
      installer/deployer may fail with a timeout error

## Using PSC in dev mode
You may want to work in PSC environment for development purposes. **For this step, you need to have conda installed on 
your machine to be able to customize this PSC environment. You can install conda 
from https://docs.conda.io/en/latest/miniconda.html for your platform.**

In order to use PSC as conda environment, you can build it in `build-dev` mode. Follow the steps below:
1. Run this command from the root folder: `./repack.sh build-dev` . It might take a while to build the dev folder. 
2. When the dev folder is created, either move the build folder (`Splunk_SA_Scientific_Python_${PLATFORM}`)  
under `$SPLUNK_HOME/etc/apps` location to link MLTK with your custom PSC or upload the tarball from the UI. 
3. Once PSC is installed, you can activate this PSC as a conda environment using the below command for Mac. 
    You can install conda from https://docs.conda.io/en/latest/miniconda.html for your platform.: 
      ```
      conda activate $SPLUNK_HOME/etc/apps/Splunk_SA_Scientific_Python_darwin_x86_64/bin/darwin_x86_64
      ``` 
   for linux, 
      ```
      conda activate $SPLUNK_HOME/etc/apps/Splunk_SA_Scientific_Python_linux_x86_64/bin/linux_x86_64
      ``` 
4. Now you can customize your PSC Python environment. Make sure to install pip first using `conda install -c conda-forge pip`
5. You can install additional packages now using `conda install` or `pip install` and once 
you refresh MLTK, your changes should be picked automatically.
6. To deactivate the PSC environment, run `conda deactivate` from the terminal.

## Note on packaging
There may be unwanted content in the build that will fail the SplunkBase App verification, e.g. hidden files. We can use Splunk Package Toolkit CLI to facilitate the packaging process.

```
# Get Splunk
wget http://releases.splunk.com/released_builds/8.0.5/splunk/osx/splunk-8.0.5-a1a6394cc5ae-darwin-64.tgz
tar -xf splunk-8.0.5-a1a6394cc5ae-darwin-64.tgz

# Run package command on the app folder
./splunk/bin/slim package ${APPDIR}_${PLATFORM}
```

## Releasing a new version of Python for Scientific Computing
If you are releasing a new PSC, you need follow these steps before running the repack scripts: 
1. Edit the value of `VERSION` variable at the top of the repack scripts.
2. Set the values of `MINICONDA_VERSION`, `LINUX_MD5`, and `OSX_MD5` variables to the appropriate value. Note that for OSX we use the `.sh` installer and not the `.pkg` installer. For the list of available miniconda versions, their respective package names, and MD5 hash, see https://repo.anaconda.com/miniconda/.
3. Update the README file under `package` directory with the correct version of included packages.
