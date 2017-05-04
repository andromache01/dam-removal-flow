This repository contains code to analyze change in mean annual one-day flow 
before and after dam removal. The repository includes code 'comparisoncode.R'
and a csv file with data on dam removals used for the analysis originally
downloaded from the USGS at https://www.sciencebase.gov/catalog/item/55071bf9e4b02e76d757c076.
This analysis was conducted as a final project by Tara Franey for class BIO594
at the University of Rhode Island. Thanks to Professor Rachel Schwartz, Professor
Art Gold and Dr. Jeff Hollister(geospatial analyis code taken from his
RhodyRStats 'geospatial_with_f' workshop at 
https://github.com/rhodyrstats/geospatial_with_sf/blob/master/geospatial_with_sf.Rmd). 

This code is designed to run as a whole in Rstudio.

The code takes an information file on dam removals,
selects those dams with associated USGS monitoring gages, and find the closest
USGS reference gage. For each of these dams, the code will retrieve daily flow
data from the USGS system. Then it will find the maximum 1 day flow for each
year (for the reference gage and the downstream dam gage), then find how much
flow at the dam gage differs for flow at reference gage, while correcting for
respective drainage areas. This distribution of this value can be compared in 
"during" dam and "after-dam" years. The result of the "during" dam average 
divided by the "after" dam average and the p-value of a t-test on the two sets
is moved into a data frame. The final output is a csv file.

Warning: parts of this code may take substantial time and require internet.
Also note that one function is used in this project. Although the standard
protocol is to include functions at the beginning of the code, there is only
one function, and it does not make much sense out of context, so it is
include where it is used.

Output: Current code prints output in "final results" data frame. 
Extra code at the end creates histograms of the during/after dam ratio for all
dams, significant dams and non significant dams.

Error column indicates issues with the data. 
'Error0' is indicated if the dam gage and reference gage are the same.
'Error1' indicates that # daily flow data is not available for at least one of 
the gages.
'Error2' occurs if there is data from both gages, but never in the same year
'Error3' is reported when there is data, but not sufficient data from both
the during dam existence and after dam removal periods to perform a t-test. 
'Error 4' indicates that the gage listed for the dam is listed for multiple 
dams, possible removed in sequence in different years, which may generate 
cumulative results, but results are reported.
