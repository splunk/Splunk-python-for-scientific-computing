# Python for Scientific Computing (PSC)

The Python for Scientific Computing app is an app that bundles Miniconda (a
commercial binary distribution of Python) and some common Python libraries
for scientific computing: numpy, scipy, pandas, scikit-learn, statsmodels.

This repo builds PSC for 3 platforms:

* Mac: <https://splunkbase.splunk.com/app/2881/>
* Linux 64-bit: <https://splunkbase.splunk.com/app/2882/>
* Windows 64-bit: <https://splunkbase.splunk.com/app/2883/>

## Building Python for Scientific Computing app

1. Update `environment.nix.yml` or `environment.win64.yml` in the repo root dir
    * Fix the major version, leave the minor version flexible, i.e. `pandas==0.25.*`
    * There's another `environment.yml` inside of each platform's folder, which act
      as the lock file to lockdown the specific versions of all dependencies
      (like `pip freeze`).
2. Run freeze task of the build scripts for each platform.
    ```
    make freeze
    ```
   the command should update the corresponding `<platform>/environment.yml` in the repo.
3. If there is any package that is not needed, add them to `<platform>/blacklist.txt`,
    and run the last step again, so the platform environment file is updated
4. Build PSC, run
    ```
    make build
    ```
    this will produce a build under `build/Splunk_SA_Scientific_Python_<platform>`
5. Package PSC, run
    ```
    make dist
    ```
    this will produce a tarball of the app in `build` directory

## Analyzing the dependency tree
If there's any package changes in the environment file, we can run
```
make analyze
```
to inspect the package dependency tree

## Software license list
To check licenses, *if you are redistributing this app*, you need
to include the proper licenses of the package redistributed packages, run
```
make license
```
to update the LICENSE file and `license_report.csv` file in the platform directory
* Note you may need to update `tools/license_extra.csv` if you included a new package

## Installing PSC
Copy it to your `$SPLUNK_HOME/etc/apps` folder
* Note, due to the size of this app, installing it via web
  installer/deployer may fail with a timeout error, can try to increase the timeout in
  `web.conf` to resolve this.

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


