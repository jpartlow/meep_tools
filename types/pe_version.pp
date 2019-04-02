# Ex: '2019.1.0' '2019.1.0-rc0-10-gabcdef' or 'latest'
type Meep_tools::Pe_version = Variant[Enum['latest'],Pattern[/^\d{4}\.\d+\.\d+.*/]]
