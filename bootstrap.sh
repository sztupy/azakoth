#!/usr/bin/env bash
pushd runner
docker build -t 'ruby-runner' .
popd

pushd runner-js
docker build -t 'js-runner' .
popd

bundle install

echo 'Docker containers built, and bundle updated'
echo
echo 'Start the server by'
echo ' LEVEL=1 bundle exec server.rb'
echo
echo 'Afterwards open the website by opening one of the following URLs:'
echo " 'static/index.html?951ab5f4-407d-4fd9-97f6-5dea67dfdbd3'"
echo " 'static/index.html?44ec23a9-7d94-446a-a5a8-d1e52ea07c4e'"
echo " 'static/index.html?4fb0d789-1b05-40cd-9c8c-046444cfc4d4'"
