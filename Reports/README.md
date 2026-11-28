# Reports

One PDF per section. Each answer starts with the original question (shaded box) and ends with a
code guide: the files to read, how to run the case, and the output to check. The files are those
handed in, in `FE_Code_Slides_Group14/Code_Group14` (paths relative to it); a case runs from the ONELAB
menus in Gmsh or with the exact commands in its `README.md`.

- [Section 1: cable selection and model setup](Section_1_Cable_Selection_and_Model_Setup.pdf)
- [Section 2: electrodynamic analysis](Section_2_Electrodynamic_Analysis.pdf)
- [Section 3: magnetoquasistatic analysis](Section_3_Magnetoquasistatic_Analysis.pdf)
- [Section 4: coupled magneto-thermal analysis](Section_4_Magnetothermal_Analysis.pdf)
- [Section 5: additional investigation, cable arrangement](Section_5_Cable_Arrangement.pdf)

## Rebuild

```sh
python3 Reports/collect_values.py   # after Source-Code/run_all.sh: printed values -> sources/data/
./Reports/build.sh
```

`sources/data/values.tex` holds every FE number quoted in the reports and slides (no number is
typed by hand); the CSV files hold the plotted data. `sources/figures/*.tex` are pgfplots figures
shared with the slides; field maps come from `../Slides/figures` (`../Slides/export_maps.sh`).
