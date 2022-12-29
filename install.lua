print("Downloading KTWSL..")
shell.run("wget https://raw.githubusercontent.com/MasonGulu/msks/main/ktwsl.lua ktwsl.lua")

print("Downloading abstractInvLib..")
shell.run("wget https://gist.githubusercontent.com/MasonGulu/57ef0f52a93304a17a9eaea21f431de6/raw/0e4bba991532b019873f659f09f09f23a0493b4d/abstractInvLib.lua abstractInvLib.lua")

print("Downloading msks")
shell.run("wget https://raw.githubusercontent.com/MasonGulu/msks/main/msks.lua msks.lua")

print("Downloading example configs")
shell.run("wget https://raw.githubusercontent.com/MasonGulu/msks/main/config config")
shell.run("wget https://raw.githubusercontent.com/MasonGulu/msks/main/listings listings")
