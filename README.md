# idle-shutdown-scripts
Scripts to shut down host or docker containers based on certain criteria.

The various variations of idle shutdown scripts created by me so far are as follows:

1. Shutting down a host computer if a jupyterlab docker container running on it, doesn't have any notebooks running (i.e., jupyterlab has been idle for some time).
2. Shutting down a host computer if a vscode container running on it, is idle

In case there are multiple containers running on your host computer, I've created a script to co-ordinate between the shutdown scripts running for the multiple containers. In case all the containers are idle, it will shut down the host.
