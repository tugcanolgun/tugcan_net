ifneq (,$(wildcard ./.env))
    include .env
    export
endif

build:
	hugo --gc --minify
deploy:
	rsync -avz -e 'ssh -p $(PORT)' --delete public/ $(USER)@$(IP):$(REMOTE_PATH)
clean:
	rm -rf public/

build_and_deploy: clean build deploy
