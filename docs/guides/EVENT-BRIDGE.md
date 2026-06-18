# AWS EventBridge Auto-Stop Guide

Automatically stops OpenShift cluster EC2 instances daily at 01:00 KST.
Works regardless of your local sleep state or cluster availability — AWS handles it directly.

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| IAM Role | `EventBridge-SSM-StopEC2` | Grants EventBridge permission to invoke SSM |
| SSM Document | `StopOpenShiftCluster` | Finds running instances by tag and stops them |
| EventBridge Rule | `openshift-cluster-autostop` | Triggers daily at 16:00 UTC (01:00 KST) |

## Daily Usage

### Check status

```bash
aws events describe-rule --name openshift-cluster-autostop
```

### Disable (working late)

```bash
aws events disable-rule --name openshift-cluster-autostop
```

### Re-enable

```bash
aws events enable-rule --name openshift-cluster-autostop
```

### Manual execution (stop now)

```bash
aws ssm start-automation-execution \
  --document-name "StopOpenShiftCluster" \
  --parameters '{"InfraID":["openshift-cluster-knd9q"],"AutomationAssumeRole":["arn:aws:iam::404388677917:role/EventBridge-SSM-StopEC2"]}'
```

### Check execution history

```bash
aws ssm describe-automation-executions \
  --filters Key=DocumentNamePrefix,Values=StopOpenShiftCluster \
  --query 'AutomationExecutionMetadataList[*].{Time:ExecutionStartTime,Status:AutomationExecutionStatus}' \
  --output table
```

## Starting the Cluster (unchanged)

```bash
./restart-cluster-instances.sh start
```

## Change Schedule

To change the stop time (e.g., 23:00 KST = 14:00 UTC):

```bash
aws events put-rule \
  --name "openshift-cluster-autostop" \
  --schedule-expression "cron(0 14 * * ? *)" \
  --state ENABLED
```

## Full Cleanup

Remove all resources when no longer needed:

```bash
aws events remove-targets --rule openshift-cluster-autostop --ids stop-openshift-cluster
aws events delete-rule --name openshift-cluster-autostop
aws ssm delete-document --name StopOpenShiftCluster
aws iam delete-role-policy --role-name EventBridge-SSM-StopEC2 --policy-name StopEC2Policy
aws iam delete-role --role-name EventBridge-SSM-StopEC2
```

## How It Works

1. EventBridge Rule triggers at 16:00 UTC daily
2. Invokes SSM Automation `StopOpenShiftCluster`
3. Queries **running** instances matching `openshift-cluster-knd9q-*` Name tag
4. Calls `StopInstances` API to stop all at once
5. No-op if instances are already stopped
