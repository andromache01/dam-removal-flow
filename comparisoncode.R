# This code is designed to run as a whole in Rstudio.

# This code is designed to take an information file on dam removals,
# select those dams with associated USGS monitoring gages, and find the closest
# USGS reference gage. For each of these dams, the code will retrieve daily flow
# data from the USGS system. Then it will find the maximum 1 day flow for each
# year (for the reference gage and the downstream dam gage), then find how much
# flow at the dam gage differs for flow at reference gage, while correcting for
# respective drainage areas. This distribution of this value can be compared in 
# "during" dam and "pre-dam" years. The result of the "during" dam average 
# divided by the "after" dam average and the p-value of a t-test on the two sets
# is moved into a data frame. The final output is a csv file.
#
# Warning: parts of this code may take substantial time and require internet.
# Also note that one function is used in this project. Although the standard
# protocol is to include functions at the beginning of the code, there is only
# one function, and it does not make much sense out of context, so it is
# include where it is used.
#
# Output: Current code prints output in "final results" data frame. 
# Extra code at the end creates histograms of the during/after dam ratio for all
# dams, significant dams and non significant dams.
# Error column indicates issues with the data. 
# 'Error0' is indicated if the dam gage and reference gage are the same.
# 'Error1' indicates that # daily flow data is not available for at least one of 
# the gages.
# 'Error2' occurs if there is data from both gages, but never in the same year
# 'Error3' is reported when there is data, but not sufficient data from both
# the during dam existence and after dam removal periods to perform a t-test. 
# 'Error 4' indicates that the gage listed for the dam is listed for multiple 
# dams, possible removed in sequence in different years, which may generate 
# cumulative results, but results are reported.



#Importing relevant libraries. Use install.packages("[packagename]") if you haven't before
library(dataRetrieval)
library(dplyr)
library(sf)
library(geosphere)
library(reshape2)
library(stringr)
library(ggplot2)

#Importing dam data: From the dam_r.csv file included in the repository. Originally sourced from https://www.sciencebase.gov/catalog/item/55071bf9e4b02e76d757c076
dam_df<-read.csv("dam_r.csv", na.strings=c(""," ","NA"),stringsAsFactors=FALSE) #reads the csv

#filtering and cleaning dam data
us_dam_df<-dam_df %>% filter(DamCountry=="USA") #only US dams
gagelisted<-us_dam_df %>%  filter(!is.na(DamAssociatedUSGSStreamGaugingStation)) %>% filter (!grepl(" ", DamAssociatedUSGSStreamGaugingStation)) #select dams with listed USGS station
bldam_coord<-as.matrix(gagelisted[,7:8]) #separates out the latitude and longitude
bldam_data<- gagelisted %>% select(DamAccessionNumber, DamName, DamRiverName,DamAssociatedUSGSStreamGaugingStation,DamState_Province,DamLatitude,DamLongitude,DamMapDatum, DamYearBuiltRemovedStructure,DamYearRemovalFinished,DamReservoirVolume_m3,DamUpstreamDrainageArea_km2, DamHeight_m, DamOperation) # separates out relevant parameters
dam_sf<-st_as_sf(bldam_data, coords = c("DamLongitude", "DamLatitude"), crs = 4326, agr = "constant") # creates a spatial data frame to detect distance
numdams<-length(dam_sf$DamName) #number of dams, will be useful later

for (i in 1:numdams){ #this makes the USGS gage number an 8 digit number. The source cut off leading zeroes, which makes automatic retrieval provide an error.
  if (nchar(bldam_data[i,4])<8){
    bldam_data[i,4]<-paste("0",bldam_data[i,4], sep="")
  }
}

#download reference gage data. You should have a 'data' file in your working directory. If not, this code creates one.
# this code based on RhodyRStats 'geospatial_with_f' workshop at https://github.com/rhodyrstats/geospatial_with_sf/blob/master/geospatial_with_sf.Rmd. 
if(!dir.exists("data")){
  dir.create("data")
}
download.file(url = "https://water.usgs.gov/GIS/dsdl/gagesII_9322_point_shapefile.zip",
              destfile = "data/refgages.zip")
unzip(zipfile = "data/refgages.zip", 
      exdir = "data")

#read reference gage data
gages<-st_read("data/gagesII_9322_sept30_2011.shp", stringsAsFactors=FALSE) #reads shapefile of all gages
gages1<-st_transform(gages, 4326) #sets the coordinate/projection system
refgages<-filter(gages1, CLASS=="Ref") #selects only reference gages
numrefgage<-length(refgages$STAID) #number of reference gages, will be useful later

#distance between dams and ref gages
bestref<-data.frame("gageID"=character(), "distance"= double()) #sets up data frames for loops
closest<-data.frame("gageID"=character(), "distance"= double())
closest<-rbind(closest,data.frame("gageID"="test","distance"=1000)) #loops works best if this data frame isn't empty to begin with
for (i in 1:numdams){ #cycles through each dam
  damdata<-dam_sf[i,] #data only for the dam
  closest$gageID<-refgages[1,]$STAID #fills the 'closest' data frame with the first reference gage, and distance between dam and that gage
  closest$distance<-st_distance(damdata, refgages[1,]) 
  for (j in 1:numrefgage){ #goes through all gages
    distance<-st_distance(damdata,refgages[j,1]) #finds distance between dam and age
    if (distance < closest$distance){ #replaces data in the data frame if this gage is closer than previous closest.
      closest$gageID<-refgages[j,1]$STAID
      closest$distance<-distance
    }
  }
  bestref<-rbind(bestref, closest) #after going through all gages, closest data gage is added to the final list
}

#download information on gages and combine data for each dam into one data frame
gagepairs<-data.frame("RefGage"=character(), "distance"=double(), "RefgDrain"=double(), "DamName"=character(), "DamBuilt"=integer(), "DamRemoved"=integer(), "DamGage"=character(), "DamgDrain"=double(), "ResVol"=double(), "DamHeight"=double(), "DamOperation"=character())
for (i in 1:length(bestref$gageID)){ #goes through each dam
  ref_gage_DA<-readNWISsite(bestref[i,1]) %>% select(drain_area_va) #gets drainage area from USGS Data system on all the listed reference gages
  dam_gage_DA<-readNWISsite(bldam_data[i,4]) %>% select(drain_area_va) #gets drainage area for 'dam' gages 
  gagepairs<-rbind(gagepairs, data.frame("RefGage"=bestref[i,1], "distance"=bestref[i,2], "RefgDrain"=ref_gage_DA, "DamName"=bldam_data[i,2], "DamBuilt"=bldam_data[i,9], "DamRemoved"=bldam_data[i,10], "DamGage"=bldam_data[i,4], "DamgDrain"=dam_gage_DA, "ResVol"=bldam_data[i,11], "DamHeight"=bldam_data[i,12], "DamOperation"=bldam_data[i,14], stringsAsFactors=FALSE)) #puts it into a dataframe with other useful parameters about the dams
}

#function to make a comparison between pre-dam and post-dam maximum 1 day flows,
# using dam gage and reference gage values
compare_flows<-function(dat){
  output<-data.frame("DamName" = character(), "AverageDifference"=double(), "PValue" = double(), "Error" = character()) #sets up data frame to report output
  l=length(dat$DamName) #sets length of the loop
  for (i in 1:l){ #goes through each Dam 
	rday1maxes<-data.frame("year"=integer(), "d1max"=double()) #creates dataframe for refernce gage flow statistic
	dday1maxes<-data.frame("year"=integer(), "d1max"=double()) #creates dataframe for dam gage statistic
    refdat<-readNWISdv(site=dat[i,1], parameterCd="00060")  #gets daily flow in cfs
    ddat<-readNWISdv(site=dat[i,7], parameterCd="00060") #same as above but for the dam gages
    if (dat[i,1]==dat[i,7]){ #reports error if the dam gage and reference gage are the same
      output<-rbind(output,data.frame("DamName" = dat[i,4], "AverageDifference"= NA, "PValue" = NA, "Error" = 'Error0'))
      next
    }
    if ((nrow(refdat)<1) | (nrow(ddat)<1)){ #reports error in output data frame if there is no data from the gages and moves to the next dam
      output<-rbind(output,data.frame("DamName" = dat[i,4], "AverageDifference"= NA, "PValue" = NA, "Error" = 'Error1'))
      next
    }
    refdat2<- refdat %>% mutate(year = format(Date, "%Y"), month = format(Date, "%m"), date= format(Date, "%d")) #moves date into more useful format
    refdat2$year<-as.integer(refdat2$year) #makes sure the year is in number format
    for (j in min(refdat2$year):max(refdat2$year)){ #goes through each year of data
      yeardat<-refdat2 %>% filter(year==j) #pulls out year's data
      if (length(yeardat$date) > 359){#makes sure there is close to a full year of data
        rday1maxes<-rbind(rday1maxes, data.frame("year"=j, "d1max"=max(yeardat$X_00060_00003))) #finds 1-day max flow for each year
      }
    }
    ddat2<- ddat %>% mutate(year = format(Date, "%Y"), month = format(Date, "%m"), date= format(Date, "%d")) #does the same as above for the dam gage data
    ddat2$year<-as.integer(ddat2$year)
    for (j in min(ddat2$year):max(ddat2$year)){
      yeardat<-ddat2 %>% filter(year==j)
      if (length(yeardat$date) > 359){
        dday1maxes<-rbind(dday1maxes, data.frame("year"=j, "d1max"=max(yeardat$X_00060_00003)))
      }
    }
    rda<-dat[i,3] #reference gage drainage area
    dda<-dat[i,8] #dam gage drainage area
    comb_maxes<-merge(rday1maxes,dday1maxes, by = 'year') #combines reference and dam gage data
    colnames(comb_maxes)<-c("year", "refgage", "damgage") #renames columns
    comb_maxes<-cbind(comb_maxes, (comb_maxes$damgage/dda)-(comb_maxes$refgage/rda)) #adds a column of the ratio between dam gage and reference gage, scaled by drainage area
    colnames(comb_maxes)<-c("year", "refgage", "damgage", "comparison") #renames columns
    if (nrow(comb_maxes)<1) { #generates error if no years with data from both gages and moves to next dam
      output<-rbind(output,data.frame("DamName" = dat[i,4], "AverageDifference"= NA, "PValue" = NA, "Error" = 'Error2'))
      next
    }
    startyear<-dat[i,5] #when dam was built
    removedyear<-dat[i,6] #when dam was removed
    if ((is.na(startyear)) | (startyear<=min(comb_maxes$year))){ #if no start year, or start year is from before beginning of data, separates data based on year dam removed only
      wdam<-comb_maxes %>% filter(year<removedyear) #data frame for during dam
      wodam<-comb_maxes %>% filter(year>removedyear) #data frame for after dam
    } else { # if dam built during period of data collection, removes 'predam' years from the wdam data set
      wdam<-comb_maxes %>% filter(year<removedyear) %>% filter (year>startyear) #data frame for during dam
      wodam<-comb_maxes %>% filter(year>removedyear) #data frame for after dam
    }
    if ((length(wdam$year)<2) | (length(wodam$year)<2)) { #generates error if not enough data
      output<-rbind(output,data.frame("DamName" = dat[i,4], "AverageDifference"= NA, "PValue" = NA, "Error" = 'Error3'))
    } else if (duplicated(dat[,7])[i]==TRUE) { #generates error if dam is duplicated - but reports output anyway)
      ttest<-t.test(wdam$comparison, wodam$comparison) #performs ttest on the two different periods
      output<-rbind(output,data.frame("DamName" = dat[i,4], "AverageDifference"= (mean(wdam$comparison)/mean(wodam$comparison)), "PValue" = ttest$p.value, "Error" = 'Error4')) #reports average difference between flow stat between during and after dam periods and pvalue
    } else {
      ttest<-t.test(wdam$comparison, wodam$comparison)
      output<-rbind(output,data.frame("DamName" = dat[i,4], "AverageDifference"= (median(wdam$comparison)/median(wodam$comparison)), "PValue" = ttest$p.value, "Error" = 'NA'))
    }
  }
  return(output)
}

final_results<-compare_flows(gagepairs)

#writes to csv
completeresults1<-merge(final_results,gagepairs, by='DamName') #puts all info in one dataframe
colnames(completeresults2)[7]<-'refdrain'
colnames(completeresults2)[11]<-'damdrain'
write.csv(completeresults, file='max1dayresults.csv') #prints data frame to csv

