AZA King of the hill
====================

You will need to have:
* ruby installed to run the server
* docker installed to run the robots

Run `bootstrap.sh` to initialize the system, which will install the appropriate docker images that will control the robots, and will also run `bundle install` for the server.

Once all installed you can run the server by typing:

```
LEVEL=1 bundle exec server.rb
```

You can chose between levels 1,2,3,4. The difference being:
* Level 1: starting level
* Level 2: double speed, each robot moves twice a second
* Level 3: walls added, robot speed increased
* Level 4: robots now steal when kicking other robots. Speed also increased and walls remain

Once the server is started you can run the client by opening the `static/index.html` with one of the team codes:

* Red: `static/index.html?951ab5f4-407d-4fd9-97f6-5dea67dfdbd3`
* Green: `static/index.html?44ec23a9-7d94-446a-a5a8-d1e52ea07c4e`
* Blue: `static/index.html?4fb0d789-1b05-40cd-9c8c-046444cfc4d4`
