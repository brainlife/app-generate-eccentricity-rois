#!/bin/bash

# output lines to log files and fail if error
# set -x
# set -e

# make directories
mkdir -p ./rois ./rois/rois ./raw

# parse inputs
prfSurfacesDir=`jq -r '.prfSurfacesDir' config.json`
minDegree=`jq -r '.min_degree' config.json` # min degree for binning of eccentricity
maxDegree=`jq -r '.max_degree' config.json` # max degree for binning of eccentricity
freesurfer=`jq -r '.freesurfer' config.json`
hemispheres="lh rh"

# make degrees loopable
minDegree=($minDegree)
maxDegree=($maxDegree)

# loop through hemispheres
for hemi in ${hemispheres}
do
	if [[ ${hemi} == 'lh' ]]; then
		hemi_out="L"
	else
		hemi_out="R"
	fi

	if [[ ${reslice} == "True" ]]; then
		# move freesurfer hemisphere ribbon into input nifti space
		input_nii_gz=`jq -r '.input_nifti' config.json`
		[ ! -f ${hemi}.ribbon.nii.gz ] && mri_vol2vol --mov $freesurfer/mri/${hemi}.ribbon.mgz --targ ${input_nii_gz} --regheader --o ${hemi}.ribbon.nii.gz
	fi

	# convert surface to gifti
	[ ! -f ${hemi}.eccentricity.func.gii ] && mris_convert -c ${prfSurfacesDir}/${hemi}.eccentricity ${freesurfer}/surf/${hemi}.pial ${hemi}.eccentricity.func.gii
	[ ! -f ${hemi}.varea.func.gii ] && mris_convert -c ${prfSurfacesDir}/${hemi}.varea ${freesurfer}/surf/${hemi}.pial ${hemi}.varea.func.gii

	# create eccentricity surface
	for DEG in ${!minDegree[@]}; do
		# genereate eccentricity bin surfaces
		[ ! -f ${hemi}.Ecc${minDegree[$DEG]}to${maxDegree[$DEG]}.func.gii ] && mri_binarize --i ./${hemi}.eccentricity.func.gii --min ${minDegree[$DEG]} --max ${maxDegree[$DEG]} --o ./${hemi}.Ecc${minDegree[$DEG]}to${maxDegree[$DEG]}.func.gii

		# map surface to volume
		SUBJECTS_DIR=${freesurfer}
		[ ! -f ROI${hemi}.Ecc${minDegree[$DEG]}to${maxDegree[$DEG]}.nii.gz ] && mri_surf2vol --o ./ROI${hemi}.Ecc${minDegree[$DEG]}to${maxDegree[$DEG]}.nii.gz --subject ./ --so ${freesurfer}/surf/${hemi}.pial ./${hemi}.Ecc${minDegree[$DEG]}to${maxDegree[$DEG]}.func.gii

		if [[ ${reslice} == "True" ]]; then
			mri_vol2vol --mov ROI${hemi}.Ecc${minDegree[$DEG]}to${maxDegree[$DEG]}.nii.gz --targ ${input_nii_gz} --regheader --o ROI${hemi}.Ecc${minDegree[$DEG]}to${maxDegree[$DEG]}.nii.gz --nearest
		fi
	done
done

