# Plasmid identification using MOB-suite

## Before running MOB-suite:
Create a new environment and install MOB-suite
mamba create -n se_plasmids \
             python=3.11 \
             mob_suite=3.1.8 \
             plasmidfinder=2.1.6 \
             spades=3.15.5 \
             mash=2.3 \
             fastani \
             -y

conda activate se_plasmids
mamba install mob_suite=3.1.8 -y

Create a new folder called "assemblies" and add all your genome assembly files (.fna).
Run the bash code
Enjoy!
