## Issues faced & fixes

### 1. PostgreSQL config path not found (version mismatch)
**Error:** `sed`/`grep` on `/etc/postgresql/16/main/postgresql.conf` → `No such file or directory`
**Cause:** Newer Ubuntu installs PostgreSQL **18**, not 16, so the config folder is `/etc/postgresql/18/main/`.
**Fix:** Detect the version instead of hard-coding it:
```bash
PG_VERSION=$(ls /etc/postgresql)
sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
```

### 2. `no pg_hba.conf entry for host` (app server can't connect to the DB)
**Error:**
```text
FATAL: no pg_hba.conf entry for host "172.31.46.54", user "fdfs", database "fdfs"
```
**Cause:** `pg_hba.conf` did not allow the app server. Two mistakes along the way:
- The `echo ... >> pg_hba.conf` was run on the **app server** (file doesn't exist there). It must run on the **data server**, where PostgreSQL runs.
- The **public IP** was added. Servers in the same VPC talk over **private IPs**, so PostgreSQL sees the app server's private IP (the IP shown in the error).

**Fix (on the data server):**
```bash
echo "host    fdfs    fdfs    <APP-SERVER-PRIVATE-IP>/32    scram-sha-256" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf
systemctl reload postgresql
```
**Lesson:** Read the error, because it tells you the exact IP to allow. Private IPs don't change on stop/start; public IPs do.

### 3. `pip install` fails: `pg_config executable not found` (psycopg2-binary)
**Error:** `Getting requirements to build wheel ... error` → `Error: pg_config executable not found.`
**Cause:** Newer Ubuntu ships **Python 3.14**. `psycopg2-binary==2.9.10` has no prebuilt package for 3.14, so pip tries to compile it from source and fails.
**Fix:** Use a version with Python 3.14 support, in `requirements.txt`:
```text
psycopg2-binary==2.9.11
```

### 4. `InvalidKeyPair.NotFound` when creating EC2 with the AWS CLI
**Error:**
```text
An error occurred (InvalidKeyPair.NotFound) when calling the RunInstances operation: The key pair 'fdfs.pem' does not exist
```
**Cause:** `--key-name` needs the **key pair name stored in AWS** (e.g. `fdfs`), not the local file name `fdfs.pem`. Key pairs are also **per region**.
**Fix:**
```bash
aws ec2 describe-key-pairs --region us-east-1 --query 'KeyPairs[].KeyName' --output table
# then use the name shown, e.g. --key-name fdfs
```

### 5. Security group ID came back as full JSON in the script
**Problem:** `sg_group_id=$(aws ec2 create-security-group ...)` stored the whole JSON response, so `run-instances --security-group-ids` failed.
**Cause:** AWS CLI commands return JSON by default.
**Fix:** Ask only for the ID:
```bash
--query 'GroupId' --output text
```
(or look the SG up again with `describe-security-groups --query "SecurityGroups[*].GroupId" --output text`)

### 6. Instance ID had a hidden `\r` (Windows line endings)
**Problem:** `terminate-instances` failed even though the instance ID looked correct.
**Error (seen with `bash -x`):**
```text
aws ec2 terminate-instances --instance-ids $'i-0681cb4bab790969b\r' i-04b654142b80339f9
An error occurred (InvalidInstanceID.NotFound) ...
```
**Cause:** Running from Git Bash on Windows can add a hidden carriage return (`\r`) to command output.
**Fix:**
```bash
instance_id=$(aws ec2 describe-instances ... --output text | tr -d '\r')
```

### 7. New code deployed but the old version still runs
**Problem:** After replacing a service's code and running `systemctl enable --now fdfs-<service>`, the old version kept running.
**Cause:** `enable --now` starts a service **only if it isn't running**. It does not restart a running one.
**Fix:**
```bash
systemctl restart fdfs-<service>
```

### 8. `InvalidInstanceID.Malformed` when deleting more than one instance
**Error:**
```text
aws ec2 terminate-instances --instance-ids 'i-0681cb4bab790969b
i-04b654142b80339f9'
An error occurred (InvalidInstanceID.Malformed) ... The instance ID 'i-0681cb4bab790969b
i-04b654142b80339f9' is malformed
```
**Cause:** Two instances had the same `Name` tag, so the query returned **two IDs on separate lines**. Quoting the variable (`"${instance_id}"`) passed both IDs as **one single argument with a newline inside**, which is not a valid instance ID.
**Fix:** Don't quote the variable here, so Bash splits it into **separate arguments**, one per ID:
```bash
aws ec2 terminate-instances --instance-ids ${instance_id}
# becomes: aws ec2 terminate-instances --instance-ids i-0681cb4bab790969b i-04b654142b80339f9
```
**Lesson:** Quotes keep text together as one argument; without quotes, Bash splits on spaces and newlines. Use `bash -x` to see exactly what each command receives.

### 9. Running the create script twice created duplicate instances
**Problem:** Every run of `create` launched a new EC2 instance with the same name, so duplicates piled up (which also caused issue 8).
**Cause:** The script created the instance without checking whether one already existed.
**Fix:** Check first and create only if nothing is found (**idempotency**: running twice gives the same result):
```bash
running_instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PREFIX}-${machine}" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text | tr -d '\r')

if [ -z "$running_instance_id" ]; then
    aws ec2 run-instances ...
else
    echo "the machine is already there no need to create the instance"
fi
```
**Note:** The check only looks at `running` instances. Running `create` again within a few seconds (while the first one is still `pending`) can still create a duplicate. Use `Values=running,pending` to cover that.