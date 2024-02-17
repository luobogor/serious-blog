pub:
	npm run release
	cd ./.deploy_git && \
	git push origin master --force
