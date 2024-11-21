# Azeroth Core WOTLK Builder

### Building Images

```build.sh``` is used to create and publish each of the images used to host the Azeroth Core services. This is run daily by the repo.

---

### Deploying To A System

```generate.sh``` converts the templates to usable files. Specify the image flavor (default/playerbots/ah-bots) and version.

If if ```-a/--ah-bots``` flag is used, then the ```mod-ah-bot/data/sql/db-world/mod_auctionhousebot.sql``` will need to be applied to the database after initialization. If this is not applied the ```ac-worldserver``` container will crash.

