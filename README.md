# OpenShift Install

The OpenShift installer `openshift-install` makes it easy to get a cluster
running on the public cloud or your local infrastructure.

To learn more about installing OpenShift, visit [docs.openshift.com](https://docs.openshift.com)
and select the version of OpenShift you are using.

## Installing the tools

After extracting this archive, you can move the `openshift-install` binary
to a location on your PATH such as `/usr/local/bin`, or keep it in a temporary
directory and reference it via `./openshift-install`.

## Cluster Instance Manager

`restart-cluster-instances.sh` manages the lifecycle of all OpenShift cluster EC2 instances.

### Basic Operations

```bash
./restart-cluster-instances.sh              # stop → start (default)
./restart-cluster-instances.sh stop          # stop only
./restart-cluster-instances.sh start         # start only
./restart-cluster-instances.sh status        # show instance status
```

### Auto-Stop Schedule

Automatically stop instances at a scheduled time every day via crontab.

```bash
./restart-cluster-instances.sh schedule          # show schedule status
./restart-cluster-instances.sh schedule on       # enable daily auto-stop at 00:00
./restart-cluster-instances.sh schedule on 23:30 # set auto-stop at 23:30
./restart-cluster-instances.sh schedule off      # disable auto-stop
```

Schedule status is displayed in the header on every command:

```
  Cluster:  openshift-cluster-xxxxx
  Region:   us-east-2
  Action:   start
  Schedule: Auto-stop at 23:30 daily (active)
```

Logs: `/tmp/cluster-autostop.log`

## License

OpenShift is licensed under the Apache Public License 2.0. The source code for this
program is [located on github](https://github.com/openshift/installer).
