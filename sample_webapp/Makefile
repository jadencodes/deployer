IMAGE?="webapp_sample"
TAG?="latest"

# quick easy run
run:
	iex -S mix

build_image:
	docker build -t $(IMAGE):$(TAG) .

build_image_tar: build_image
	mkdir docker_images 2> /dev/null || true
	docker save -o docker_images/sample_app.tar webapp_sample:latest
