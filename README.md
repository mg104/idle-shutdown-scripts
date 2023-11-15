# idle-shutdown-scripts
#### I mainly created these scripts to shutdown idle EC2 instances running jupyterlab, to avoid unnecessary costs from idle EC2 instances

**TLDR**: Scripts to shut down host of docker containers based on certain criteria. The host could be anything (your local PC, AWS EC2 instance, GCP VM Instance, etc)

The various variations of idle shutdown scripts created by me so far are as follows:

1. idle-shutdown-scripts/jupyterlab/jupyterlab-idle-shutdown-script.sh: Shutting down a host computer if a jupyterlab docker container running on it, doesn't have any notebooks running (i.e., jupyterlab has been idle for some time).

   NOTE: The above shutdown script for jupyterlab will work only if you have set up the following variables in the file /home/${USER}/.jupyter/jupyter_notebook_config.py in your jupyterlab docker container:
   * c.MappingKernelManager.cull_busy = False (This will ensure that your jupyterlab doesn't shut down if its busy running some code)
   * c.MappingKernelManager.cull_connected = True (This will ensure that your jupyterlab will shut down even if its browser window is open on your computer, but its otherwise lying idle)
   * c.MappingKernelManager.cull_idle_timeout = 1800 (This will ensure that your jupyterlab will shut down after 1800 seconds, or 30 minutes, of your jupyterlab server lying idle)
   * c.MappingKernelManager.cull_interval = 10 (This will check if the notebook has been idle, at each 10 second interval)
   * You will also have to launch your docker container using the entrypoint: "jupyter lab --NotebookApp.token=${JUPYTER_TOKEN}" where JUPYTER_TOKEN is an environment variable that you can declare while creating your container. This token will be used inside the shutdown script, to access the jupyerlab's url: localhost:8888/api/sessions?token=${JUPYTER_TOKEN} (this url tells us if the jupyterlab is idle or not)

For example of how to make such a docker container, refer to an example dockerfile and its associated files in my github repo: https://github.com/mg104/sos-notebook-repo.git
    
2. idle-shutdown-scripts/vscode/vscode-idle-shutdown-script.sh: Shutting down a host computer if a vscode container running on it, is idle.

3. idle-shutdown-scripts/idle-shutdown-collaborator.sh: In case there are multiple containers running on your host computer, I've created a script to co-ordinate between the shutdown scripts running for the multiple containers. In case all the containers are idle, this coordinator script will shut down the host.

If you have 2 jupyterlab containers running in your host computer, do the following to schedule idle shutdown scripts:
* Clone this repo to your `/home/madhur`, by running `cd /home/madhur && git clone git@github.com:mg104/idle-shutdown-scripts.git`
* Open linux terminal
* Enter `sudo crontab -e` to open the crontab (You have to use `sudo` since shutting down a host computer usually requires sudo privileges)
* Enter the following command on a new line of the crontab:
   `/home/madhur/idle-shutdown-scripts/idle-shutdown-collaborator.sh -- /home/madhur/idle-shutdown-scripts/jupyterlab/jupyterlab-idle-shutdown-script.sh -n jupyterlab-container1 -l /home/madhur/jupyterlab-container1-shutdown.logs -- /home/madhur/idle-shutdown-scripts/jupyterlab/jupyterlab-idle-shutdown-script.sh -n jupyterlab-container2 -l /home/madhur/jupyterlab-container2-shutdown.logs`
* Reboot your host computer

**ASSUMPTIONS**:
1. Your username is `madhur`
2. Your first container is named `juypterlab-container1`
3. Your second container is named `jupyterlab-container2`
4. You want log files of the shutdown scripts to be located at positions mentioned after -l in the above code
