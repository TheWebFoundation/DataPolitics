To setup your own instance with LookingGlass:
1. Setup LookingGlass and DocManager instances by following steps 1-5 at
https://github.com/TransparencyToolkit/Test-Data/blob/master/getting_started.md.

2. Start DocManager

4. In this directory, run: ruby datapolitics_index_script.rb.
If DocManager is running somewhere other than localhost:3000, the path for
this may need to be adjusted.

5. In LookingGlass/config/initializers/project_config.rb, change the
PROJECT_CONFIG environment variable to "datapolitics". Then, start LookingGlass.
