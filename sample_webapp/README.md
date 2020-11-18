# SampleWebapp

This is a sample web app intended to demonstrate the deployer functionality. It is a simple webserver written in elixir and using the cowboy web library.

## Building

To run the app locally:

```console
	make run
```

To build the docker image meant to be deployed:
```console
	make build_image
```

To build the docker images tar file for the deployer to upload:
```console
	make build_image_tar
```
