# Deployer

Deploy EC2 and upload the current version of an application to it.
Any application can be run on an ec2 instance by only having a small manifest file in its directory. While this iteration currently only does the basics, it demonstrates the framework for more custimizablity.

**NOTE:** This is meant as a proof of concept, many "unhappy paths", are not validated (missing files, bad vpc) and are exited abruptly.

## Who is this for?

This application is intended to be used by _non_ cluster admins; people that just need to deploy their app without all the fuss of deploying ec2, security groups, etc...
The bottom line is to give any developer the means to deploy their app to the cloud while having some guardrails and ease of access.

For example, if a front end developer needs to deploy their webserver to the cloud for QE and Marketing to able to verify. All they would need to do is create a small manifest in their frontend repo and use this tool to get it up and running in minutes.

### Assumed AWS layout

Since this tool is intended to be used by developers and not devops/sre, the VPC/Subnets/SG must already be created (for this iteration, see TODO). But only the VPC needs to be provided in the commandline. The others can be selected interactively.

A rough design of what the aws infrastructure would look like is this:

![AWS Layout]("images/example_aws_layout.png")

## Building

To build deployer, run:
```console
make build
```

## Running

**NOTE:** To run, you must have the following environment variables set: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

To run:
```console
./deployer <path_to_app_dir> --vpc_id <vpc_id> --key_pair <aws_key_pair> [--private_key <key_path>] [--known_hosts <known_hosts_path]
```

Running this will load the `manifest.yaml` file from the `path_to_app_dir` directory.

The following steps will then be run:
1. Fetch available subnets in vpc. User chooses one.
2. Fetch available security groups in vpc. User chooses one.
3. Add ingress rule to sg on port 22 from **ONLY** the requester for ssh access. If it already exists, continue.
4. Add ingress rule to sg on port 80. If it already exists, continue.
5. Launch instance using specified parameters from user and manifest. Wait until running. Output public ip.
6. Establish SSH access. Install dependencies from manifest.
7. Establish SFTP access. Upload files from manifest.
8. Run start commands for application defined in manifest.
9. At this point, the application is up and running and can be connected via the IP output from step 5.

### Application Manifest

The desired application to launch needs to have a `manifest.yaml` in the root of its directory.

A sample manifest looks like this:

```yaml
name: "Some Test App"

# list of dependencies to install (`apt install -y`)
dependencies:
  - vim
  - git

# required user to log into via ssh
username: "root"

# ami to use
ami: "ami-0aef57767f5404a3c" #base ubuntu20

# instance type
instance_type: "t2.micro"

# list of source/dest files to move to the ec2 before starting
copy_files:
  - src: "localfile/path/foo.tar"
    dest: "foo.tar

# required commands to start app once its on an ec2 instance
start_cmds:
  - echo "Starting app"
  - git clone http://foo/
```

## Documentation

Documentation can be generated from the comments:
```console
mix docs
```

To view, open `doc/index.html` in your browser.

## Next Steps (TODO)

* TESTS!! Most of this code is wrapper around the `ex_aws` library, which itself is a _thin_ REST wrapper. Mocking all of this will be time consuming.
* More safety checks. For example, if a file doesnt exist, it will exit uncleanly
* Allow generation of Security Groups and Subnets on the fly (another choice for the user)
* Make ports configurable in the manifest (currently only 80 is open to the world)

## Limitations

* OpenSSH keys are not supported due to the underlying erlang library, only PKCS8 (.pem)
* Currently commands are expected to work with apt, although other package managers could be configured
* Only port 80 is opened to the world, this should be adapted to the manifest file
* Only supports one region (configurable, but must be rebuilt)

## Assumptions

* Key pair already generated/imported
* VPC/Subnets/SG already created
