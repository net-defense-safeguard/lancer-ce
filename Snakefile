import pandas as pd
import yaml
import pyaml
import json
from slugify import slugify

configfile: 'config.yaml'

rule all:
    input:
        config['targets']
    
rule convert_xlsx_to_tsv:
    input:
        config['xlsx']['filename']
    output:
        'tsv/{table}_list.tsv'
    run:
        shell(f'mkdir -p tsv')
        pd.read_excel(input[0], sheet_name = config['xlsx']['tables'][wildcards.table]).to_csv(output[0], sep = '\t', index = False)

rule convert_tsv_to_intermediate_yaml:
    input:
        rules.convert_xlsx_to_tsv.output
    output:
        'intermediate_yaml/{table}_list.yaml'
    run:
        shell(f'mkdir -p intermediate_yaml')
        table = pd.read_table(input[0])
        table.columns.values[0] = 'Name'
        table = table.rename(columns = {colname: slugify(colname, lowercase=False) for colname in table.columns.values})
        table['ID'] = table['Name'].apply(lambda name: slugify(name, lowercase=False, sep='_'))
        table = table.set_index('ID')
        open(output[0], 'w').write(pyaml.dump(table.to_dict('index'), indent = 4))

rule split_intermediate_yaml:
    input:
        rules.convert_tsv_to_intermediate_yaml.output
    output:
        dynamic('intermediate_yaml/{table}/{item}.yaml')
    run:
        shell(f'mkdir -p intermediate_yaml/{wildcards.table}')
        table = yaml.safe_load(open(input[0]))
        for item in table:
            open(f'intermediate_yaml/{wildcards.table}/{item}.yaml', 'w').write(pyaml.dump(table[item]))

