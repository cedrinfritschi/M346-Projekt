<a href="https://github.com/cedrinfritschi/M346-Projekt/releases/latest">![release](https://img.shields.io/github/v/release/cedrinfritschi/M346-Projekt?style=flat-square&color=%230962b5)</a>
<a href="https://github.com/cedrinfritschi/M346-Projekt">![Repo-size](https://img.shields.io/github/repo-size/cedrinfritschi/M346-Projekt?style=flat-square&color=%23fa0ce2)</a>
<a href="https://github.com/cedrinfritschi/M346-Projekt/graphs/contributors">![Contributors](https://img.shields.io/github/contributors/cedrinfritschi/M346-Projekt?style=flat-square&color=%236804ba)</a>

# M365-Projekt
This repository was created for a school project. We had to create an IaC that spins up two EC2 instances with one of them hosting a database and the other a CMS. We chose WordPress as our CMS and MySQL as our DBMS.

Dieses Repository wurde für ein Schulprojekt erstellt. Wir mussten eine IaC erstellen, die zwei EC2-Instanzen bereitstellt, von denen eine eine Datenbank hostet und die andere ein CMS. Wir haben WordPress als unser CMS und MySQL als unser DBMS gewählt.

## User Guide
This is a quick explanation on how to use the scripts. For a more detailed guide and explanation, visit the ![Wiki](https://github.com/cedrinfritschi/M346-Projekt/wiki/2.-Docs-(EN))

1. Make sure your AWS credentials and config are correct and up to date. (Check out the ![Wiki](https://github.com/cedrinfritschi/M346-Projekt/wiki/2.-Docs-(EN)#aws-credentials) for more info)
```bash
cat ~/.aws/credentials
cat ~/.aws/config
```
2. Clone the repository locally.
```bash
git clone https://github.com/cedrinfritschi/M346-Projekt.git
```
3. Move to the `M346-Projekt/iac` directory
```bash
cd M346-Projekt/iac
```
4. Make the scripts executable (if not already)
```bash
chmod +x ./iac-init.sh ./iac-clean.sh
```
5. Run the `iac-init.sh`
```bash
./iac-init.sh
```
6. Once you are finished and ready to terminate the instances, run:
```bash
./iac-clean.sh
```
## Documentation
Our team has provided detailed explanation about what the scripts are doing in both English and German.
- ![Docs (DE)](https://github.com/cedrinfritschi/M346-Projekt/wiki/1.-Docs-(DE))
- ![Docs (EN)](https://github.com/cedrinfritschi/M346-Projekt/wiki/2.-Docs-(EN))

The documentation is on this repository's Wiki and contains:
- How to setup your AWS credentials
- How to use the scripts
- What each section of the code is doing

## Tests
Our team has went through some test cases to make sure that everything works as expected.

These are of course documented as well in both English and German. They are available on the Wiki.
- ![Tests (DE)](https://github.com/cedrinfritschi/M346-Projekt/wiki/3.-Tests-(DE))
- ![Tests (EN)](https://github.com/cedrinfritschi/M346-Projekt/wiki/4.-Tests-(EN))

## Project reflection
Our team has provided a project reflection. This includes things like:
- What each member enjoyed the most about this project
- Any areas that could be improved
- Things to keep in mind for another project like this one

You will also find this on the Wiki:
- ![Reflection (DE)](https://github.com/cedrinfritschi/M346-Projekt/wiki/5.-Reflection-(DE))
- ![Reflection (EN)](https://github.com/cedrinfritschi/M346-Projekt/wiki/6.-Reflection-(EN))
