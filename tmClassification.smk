rule compareTargetsToTms:
	input:
		tms= "mappings/nonAnchoredMergeReads/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.splicing_status:all.endSupport:all.gff",
		targetedSegments=config["TARGETSDIR"] + "{capDesign}_primary_targets.exons.reduced.gene_type.segments.gtf"
	output: "mappings/nonAnchoredMergeReads/vsTargets/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.gfftsv.gz"
	shell:
		'''
uuidTmpOut=$(uuidgen)
bedtools intersect -wao -a {input.targetedSegments} -b {input.tms} |gzip > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule getTargetCoverageStats:
	input: "mappings/nonAnchoredMergeReads/vsTargets/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.gfftsv.gz"
	output: config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.min{minReadSupport}reads.targetCoverage.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
for type in `zcat {input} | extractGffAttributeValue.pl gene_type | sort -T {config[TMPDIR]} |uniq`; do
all=$(zcat {input} | fgrep "gene_type \\"$type\\";" | extractGffAttributeValue.pl transcript_id | sort -T {config[TMPDIR]} |uniq|wc -l)
detected=$(zcat {input} | fgrep "gene_type \\"$type\\";" | awk '$NF>0' | extractGffAttributeValue.pl transcript_id | sort -T {config[TMPDIR]} |uniq|wc -l)
let undetected=$all-$detected || true
echo -e "{wildcards.techname}Corr{wildcards.corrLevel}\t{wildcards.capDesign}\t{wildcards.sizeFrac}\t{wildcards.barcodes}\t$type\t$all\t$detected" | awk '{{print $0"\t"$7/$6}}'
done > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule aggTargetCoverageStats:
	input: lambda wildcards: expand(config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.min{minReadSupport}reads.targetCoverage.stats.tsv",filtered_product_merge,  techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNS, sizeFrac=SIZEFRACS, barcodes=BARCODESpluSMERGED, minReadSupport=wildcards.minReadSupport)
#lambda wildcards: expand(config["STATSDATADIR"] + "{techname}Corr{corrLevel}_{capDesign}_pooled.targetCoverage.stats.tsv", techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNS)
	output: config["STATSDATADIR"] + "all.min{minReadSupport}reads.targetCoverage.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
echo -e "seqTech\tcorrectionLevel\tcapDesign\tsizeFrac\ttissue\ttargetType\ttotalTargets\tdetectedTargets\tpercentDetectedTargets" > {config[TMPDIR]}/$uuidTmpOut
cat {input} | grep -v erccSpikein | sed 's/Corr0/\tNo/' | sed 's/Corr{lastK}/\tYes/'| sort -T {config[TMPDIR]}  >> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule plotTargetCoverageStats:
	input: config["STATSDATADIR"] + "all.min{minReadSupport}reads.targetCoverage.stats.tsv"
	output: returnPlotFilenames(config["PLOTSDIR"] + "targetCoverage.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.min{minReadSupport}reads.targetCoverage.stats")
	params:
		filterDat=lambda wildcards: merge_figures_params(wildcards.capDesign, wildcards.sizeFrac, wildcards.barcodes, wildcards.corrLevel, wildcards.techname)
	shell:
		'''
echo "
library(cowplot)
library(plyr)
library(scales)
library(gridExtra)
library(grid)
library(ggplotify)

dat <- read.table('{input}', header=T, as.is=T, sep='\\t')
{params.filterDat[10]}
{params.filterDat[0]}
{params.filterDat[1]}
{params.filterDat[2]}
{params.filterDat[3]}
{params.filterDat[4]}
{params.filterDat[5]}
{params.filterDat[8]}


plotWidth = plotWidth + 2
plotHeight = plotHeight + 2

plotBase <- \\"ggplot(dat, aes(x=factor(correctionLevel), y=percentDetectedTargets, fill=targetType)) +
geom_bar(width=0.75,stat='identity', position=position_dodge(width=0.9)) +
scale_fill_manual(values={long_Rpalette}) +
geom_hline(aes(yintercept=1), linetype='dashed', alpha=0.7) +
geom_text(size=geom_textSize, aes(group=targetType, y=0.01, label = paste(sep='',percent(percentDetectedTargets),' / ','(',comma(detectedTargets),')')), angle=90, size=2.5, hjust=0, vjust=0.5, position = position_dodge(width=0.9)) +
ylab('% targeted regions detected') +
xlab('{params.filterDat[6]}') +
scale_y_continuous(limits = c(0, 1), labels = scales::percent)+
{params.filterDat[7]}
{GGPLOT_PUB_QUALITY} + \\"

{params.filterDat[12]}

save_plot('{output[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output[2]}', pXy, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output[3]}', pXy, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output[4]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output[5]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output[6]}', pYx, base_width=wYxPlot, base_height=hYxPlot)
save_plot('{output[7]}', pYx, base_width=wYxPlot, base_height=hYxPlot)

save_plot('{output[8]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)
save_plot('{output[9]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)


" > $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r
cat $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r | R --slave


		'''


rule gffcompareToAnnotation:
	input:
		annot=lambda wildcards: CAPDESIGNTOANNOTGTF[wildcards.capDesign],
		tm="mappings/nonAnchoredMergeReads/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.gff"
	output: 
		standard="mappings/nonAnchoredMergeReads/gffcompare/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.simple.tsv",
		adjustedSn="mappings/nonAnchoredMergeReads/gffcompare/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.adj.simple.tsv"

	shell:
		'''
pref=$(basename {output.standard} .simple.tsv)
annotFullPath=$(fullpath {input.annot})
uuid=$(uuidgen)
outdir="$PWD/$(dirname {output.standard})"
cp {input.tm} {config[TMPDIR]}/$uuid
cd {config[TMPDIR]}
gffcompare -o ${{uuid}}PREF -r $annotFullPath $uuid
cat ${{uuid}}PREF.tracking | simplifyGffCompareClasses.pl - > ${{uuid}}PREF.simple.tsv

mv ${{uuid}}PREF.simple.tsv $outdir/$(basename {output.standard})
mv ${{uuid}}PREF.loci $outdir/$pref.loci
mv ${{uuid}}PREF.stats $outdir/$pref
mv ${{uuid}}PREF.tracking $outdir/$pref.tracking
mv ${{uuid}}PREF.$uuid.refmap $outdir/$pref.refmap
mv ${{uuid}}PREF.$uuid.tmap $outdir/$pref.tmap

##### ADJUSTED METRICS (gffcompare -R)

pref=$(basename {output.adjustedSn} .simple.tsv)
gffcompare -o ${{uuid}}PREF -r $annotFullPath -R $uuid
cat ${{uuid}}PREF.tracking | simplifyGffCompareClasses.pl - > ${{uuid}}PREF.simple.tsv
mv ${{uuid}}PREF.simple.tsv $outdir/$(basename {output.adjustedSn})
mv ${{uuid}}PREF.loci $outdir/$pref.loci
mv ${{uuid}}PREF.stats $outdir/$pref
mv ${{uuid}}PREF.tracking $outdir/$pref.tracking
mv ${{uuid}}PREF.$uuid.refmap $outdir/$pref.refmap
mv ${{uuid}}PREF.$uuid.tmap $outdir/$pref.tmap

		'''

if SIRVpresent:
	rule gffcompareToSirvAnnotation:
		input:
			annot=config["SIRVgff"],
			tm="mappings/nonAnchoredMergeReads/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.{filt}.tmerge.min{minReadSupport}reads.splicing_status:all.endSupport:all.gff"
		output: "mappings/nonAnchoredMergeReads/gffcompare/SIRVs/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.{filt}.tmerge.min{minReadSupport}reads.vs.SIRVs.simple.tsv"
		shell:
			'''
pref=$(basename {output} .simple.tsv)
annotFullPath=$(fullpath {input.annot})
uuid=$(uuidgen)
outdir="$PWD/$(dirname {output})"
cat {input.tm} | awk '$1=="SIRVome_isoforms" ' > {config[TMPDIR]}/$uuid
cd {config[TMPDIR]}
gffcompare -o ${{uuid}}PREF -r $annotFullPath $uuid
cat ${{uuid}}PREF.tracking | simplifyGffCompareClasses.pl - > ${{uuid}}PREF.simple.tsv
mv ${{uuid}}PREF.simple.tsv $outdir/$(basename {output})
mv ${{uuid}}PREF.loci $outdir/$pref.loci
mv ${{uuid}}PREF.stats $outdir/$pref
mv ${{uuid}}PREF.tracking $outdir/$pref.tracking
mv ${{uuid}}PREF.$uuid.refmap $outdir/$pref.refmap
mv ${{uuid}}PREF.$uuid.tmap $outdir/$pref.tmap


			'''

rule getGffCompareSirvStats:
	input:"mappings/nonAnchoredMergeReads/gffcompare/SIRVs/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.{filt}.tmerge.min{minReadSupport}reads.vs.SIRVs.simple.tsv"
	output: config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.{filt}.tmerge.min{minReadSupport}reads.vs.SIRVs.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
uuid=$(uuidgen)
file=$(dirname {input})/$(basename {input} .simple.tsv)
for level in `echo Baselevel Exonlevel Intronchainlevel Intronlevel Locuslevel Transcriptlevel`; do

cat $file |grep "level:" > {config[TMPDIR]}/$uuid || true
SnDEFAULT=0
SpDEFAULT='NA'

Sn=`cat {config[TMPDIR]}/$uuid |sed 's/ //g'| sed 's/:/\\t/'|sed 's/|$//'|sed 's/|/\\t/g' | awk -v l=$level '$1==l' |cut -f2`
Sn=${{Sn:-$SnDEFAULT}} #see https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/ default variable assignments


Sp=`cat {config[TMPDIR]}/$uuid |sed 's/ //g'| sed 's/:/\\t/'|sed 's/|$//'|sed 's/|/\\t/g' | awk -v l=$level '$1==l' |cut -f3`
Sp=${{Sp:-$SpDEFAULT}} #see https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/ default variable assignments


echo -e "{wildcards.techname}Corr{wildcards.corrLevel}\t{wildcards.capDesign}\t{wildcards.sizeFrac}\t{wildcards.barcodes}\t$level\t$Sn\t$Sp";
done |sed 's/level//g' > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule aggGffCompareSirvStats:
	input: lambda wildcards:expand(config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.{filt}.tmerge.min{minReadSupport}reads.vs.SIRVs.stats.tsv", filtered_product_merge, techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNS, sizeFrac=SIZEFRACS, barcodes=BARCODESpluSMERGED, minReadSupport=wildcards.minReadSupport, filt=wildcards.filt)
	output: config["STATSDATADIR"] + "all.{filt}.tmerge.min{minReadSupport}reads.vs.SIRVs.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
echo -e "seqTech\tcorrectionLevel\tcapDesign\tsizeFrac\ttissue\tlevel\tmetric\tvalue" > {config[TMPDIR]}/$uuidTmpOut
cat {input} | awk '{{print $1"\\t"$2"\\t"$3"\\t"$4"\\t"$5"\\tSn\\t"$6"\\n"$1"\\t"$2"\\t"$3"\\t"$4"\\t"$5"\\tPr\\t"$7}}'| sed 's/Corr0/\tNo/' | sed 's/Corr{lastK}/\tYes/' | sort -T {config[TMPDIR]}  >> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule plotGffCompareSirvStats:
	input:config["STATSDATADIR"] + "all.{filt}.tmerge.min{minReadSupport}reads.vs.SIRVs.stats.tsv"
	output: returnPlotFilenames(config["PLOTSDIR"] + "tmerge.vs.SIRVs.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.{filt}.tmerge.min{minReadSupport}reads.vs.SIRVs.stats")
	params:
		filterDat=lambda wildcards: merge_figures_params(wildcards.capDesign, wildcards.sizeFrac, wildcards.barcodes, wildcards.corrLevel, wildcards.techname)
	shell:
		'''
echo "
library(cowplot)
library(plyr)
library(scales)
library(gridExtra)
library(grid)
library(ggplotify)
library(ggforce)

cbPalette <- c('Sn'='#ffb366', 'Pr'='#2d8659')
dat <- read.table('{input}', header=T, as.is=T, sep='\\t')
{params.filterDat[10]}
{params.filterDat[0]}
{params.filterDat[1]}
{params.filterDat[2]}
{params.filterDat[3]}
{params.filterDat[4]}
{params.filterDat[5]}
{params.filterDat[8]}

plotHeight = plotHeight +1
plotWidth = plotWidth +1
plotBase <- \\"ggplot(dat, aes(x=level, y=value)) +
geom_mark_rect(aes(filter = level == 'Transcript' & metric == 'Pr'), size=2, expand = unit(7, 'mm'), radius = unit(4, 'mm'), color='#4d4d4d', fill='#ffff00') +
geom_point(aes(color=metric), shape=18, size=10, alpha=0.7) +
scale_colour_manual (values=cbPalette, name='Metric', breaks=c('Sn', 'Pr'))+
ylab('Sn | Pr (%)') +
xlab('Evaluation level') +
scale_y_continuous() +
expand_limits(y=c(0,100))+
theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
{GGPLOT_PUB_QUALITY} + \\"

{params.filterDat[12]}

save_plot('{output[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output[2]}', pXy, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output[3]}', pXy, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output[4]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output[5]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output[6]}', pYx, base_width=wYxPlot, base_height=hYxPlot)
save_plot('{output[7]}', pYx, base_width=wYxPlot, base_height=hYxPlot)

save_plot('{output[8]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)
save_plot('{output[9]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)


" > $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r
cat $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r | R --slave
		'''

if SIRVpresent:
	rule getSirvDetectionStats:
		input:
			gffC="mappings/nonAnchoredMergeReads/gffcompare/SIRVs/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.vs.SIRVs.simple.tsv",
#			tm="mappings/nonAnchoredMergeReads/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.splicing_status:all.endSupport:all.gff",
			sirvInfo=config["SIRVinfo"]
		output:config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.vs.SIRVs.detection.stats.tsv"
		shell:
			'''
uuid=$(uuidgen)
uuidTmpOut=$(uuidgen)
sirvDetectionStats.pl {input.sirvInfo} $(dirname {input.gffC})/$(basename {input.gffC} .simple.tsv).refmap > {config[TMPDIR]}/$uuid
cat {config[TMPDIR]}/$uuid | while read id l c ca; do echo -e "{wildcards.techname}Corr{wildcards.corrLevel}\t{wildcards.capDesign}\t{wildcards.sizeFrac}\t{wildcards.barcodes}\t$id\t$l\t$c\t$ca"; done > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

			'''

rule aggSirvDetectionStats:
	input: lambda wildcards:expand(config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.vs.SIRVs.detection.stats.tsv", filtered_product_merge, techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNS, sizeFrac=SIZEFRACS, barcodes=BARCODESpluSMERGED, minReadSupport=wildcards.minReadSupport)
	output: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.vs.SIRVs.detection.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
echo -e "seqTech\tcorrectionLevel\tcapDesign\tsizeFrac\ttissue\tSIRVid\tlength\tconcentration\tdetectionStatus" > {config[TMPDIR]}/$uuidTmpOut
cat {input} | sed 's/Corr0/\tNo/' | sed 's/Corr{lastK}/\tYes/' | sort -T {config[TMPDIR]}  >> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule plotSirvDetectionStats:
	input:config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.vs.SIRVs.detection.stats.tsv"
	output: returnPlotFilenames(config["PLOTSDIR"] + "tmerge.vs.SIRVs.detection.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.vs.SIRVs.detection.stats")
	params:
		filterDat=lambda wildcards: merge_figures_params(wildcards.capDesign, wildcards.sizeFrac, wildcards.barcodes, wildcards.corrLevel, wildcards.techname)
	shell:
		'''
echo "
library(cowplot)
library(plyr)
library(scales)
library(gridExtra)
library(grid)
library(ggplotify)

palette <- c('end-to-end' = '#00e600', 'absent' = '#666666', 'partial' = '#ff0066')
dat <- read.table('{input}', header=T, as.is=T, sep='\\t')

{params.filterDat[10]}
{params.filterDat[0]}
{params.filterDat[1]}
{params.filterDat[2]}
{params.filterDat[3]}
{params.filterDat[4]}
{params.filterDat[5]}
{params.filterDat[8]}


plotBase <- \\"ggplot(dat, aes(x=concentration, y=length, color=detectionStatus)) + geom_point(alpha=0.8, shape=18) +
coord_trans(x='log2') +
scale_color_manual(values=palette) +
xlab('SIRV molarity (fmol/uL)') +
ylab('SIRV length (nt)') +
{GGPLOT_PUB_QUALITY} + \\"

{params.filterDat[12]}

save_plot('{output[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output[2]}', pXy, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output[3]}', pXy, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output[4]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output[5]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output[6]}', pYx, base_width=wYxPlot, base_height=hYxPlot)
save_plot('{output[7]}', pYx, base_width=wYxPlot, base_height=hYxPlot)

save_plot('{output[8]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)
save_plot('{output[9]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)


" > $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r
cat $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r | R --slave



		'''


rule colorBedAccordingToGffCompare:
	input:
		classes="mappings/nonAnchoredMergeReads/gffcompare/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:all.endSupport:{endSupport}.vs.gencode.simple.tsv",
		tm="mappings/nonAnchoredMergeReads/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:all.endSupport:{endSupport}.bed"
	output: "mappings/nonAnchoredMergeReads/colored/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.bed"
	shell:
			'''
uuidTmpOut=$(uuidgen)
colorNovelTxBed.pl {input.classes} {input.tm} > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

			'''


rule getGffCompareStats:
	input: "mappings/nonAnchoredMergeReads/gffcompare/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.simple.tsv"
	output: config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
cat {input} |cut -f2 | sort -T {config[TMPDIR]} |uniq -c | awk -v s={wildcards.techname}Corr{wildcards.corrLevel} -v c={wildcards.capDesign} -v si={wildcards.sizeFrac} -v b={wildcards.barcodes} '{{print s"\t"c"\t"si"\t"b"\t"$2"\t"$1}}' | sed 's/Corr0/\tNo/' | sed 's/Corr{lastK}/\tYes/' > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule getGffCompareGencodeSnPrStats:
	input:"mappings/nonAnchoredMergeReads/gffcompare/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.adj.simple.tsv"
	output: config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.SnPr.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
uuid=$(uuidgen)
file=$(dirname {input})/$(basename {input} .simple.tsv)
for level in `echo Baselevel Exonlevel Intronchainlevel Intronlevel Locuslevel Transcriptlevel`; do
cat $file |grep "level:" > {config[TMPDIR]}/$uuid || true
SnDEFAULT=0
SpDEFAULT='NA'


Sn=`cat {config[TMPDIR]}/$uuid |sed 's/ //g'| sed 's/:/\\t/'|sed 's/|$//'|sed 's/|/\\t/g' | awk -v l=$level '$1==l' |cut -f2` 
Sn=${{Sn:-$SnDEFAULT}} #see https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/ default variable assignments

Sp=`cat {config[TMPDIR]}/$uuid |sed 's/ //g'| sed 's/:/\\t/'|sed 's/|$//'|sed 's/|/\\t/g' | awk -v l=$level '$1==l' |cut -f3` 
Sp=${{Sp:-$SpDEFAULT}} #see https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/ default variable assignments

echo -e "{wildcards.techname}Corr{wildcards.corrLevel}\t{wildcards.capDesign}\t{wildcards.sizeFrac}\t{wildcards.barcodes}\t$level\t$Sn\t$Sp";
done |sed 's/level//g' > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule aggGffCompareGencodeSnPrStats:
	input: lambda wildcards:expand(config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.SnPr.stats.tsv", filtered_product_merge, techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNS, sizeFrac=SIZEFRACS, barcodes=BARCODESpluSMERGED, endSupport=wildcards.endSupport, minReadSupport=wildcards.minReadSupport, splicedStatus=wildcards.splicedStatus)
	output: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.SnPr.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
echo -e "seqTech\tcorrectionLevel\tcapDesign\tsizeFrac\ttissue\tlevel\tmetric\tvalue" > {config[TMPDIR]}/$uuidTmpOut
cat {input} | awk '{{print $1"\\t"$2"\\t"$3"\\t"$4"\\t"$5"\\tSn\\t"$6"\\n"$1"\\t"$2"\\t"$3"\\t"$4"\\t"$5"\\tPr\\t"$7}}'| sed 's/Corr0/\tNo/' | sed 's/Corr{lastK}/\tYes/' | sort -T {config[TMPDIR]}  >> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule plotGffCompareGencodeSnPrStats:
	input:config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.SnPr.stats.tsv"
	output: returnPlotFilenames(config["PLOTSDIR"] + "tmerge.vs.gencode.SnPr.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.SnPr.stats")
	params:
		filterDat=lambda wildcards: merge_figures_params(wildcards.capDesign, wildcards.sizeFrac, wildcards.barcodes, wildcards.corrLevel, wildcards.techname)
	shell:
		'''
echo "
library(cowplot)
library(plyr)
library(scales)
library(gridExtra)
library(grid)
library(ggplotify)

cbPalette <- c('Sn'='#ffb366', 'Pr'='#2d8659')
dat <- read.table('{input}', header=T, as.is=T, sep='\\t')
{params.filterDat[10]}
{params.filterDat[0]}
{params.filterDat[1]}
{params.filterDat[2]}
{params.filterDat[3]}
{params.filterDat[4]}
{params.filterDat[5]}
{params.filterDat[8]}

plotHeight = plotHeight +1
plotWidth = plotWidth +1

plotBase <- \\"ggplot(dat, aes(x=level, y=value)) +
geom_point(aes(color=metric), shape=18, size=10, alpha=0.7) +
scale_colour_manual (values=cbPalette, name='Metric', breaks=c('Sn', 'Pr'))+
ylab('Sn | Pr (%)') +
xlab('Evaluation level') +
scale_y_continuous() +
expand_limits(y=c(0,100))+
theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
{GGPLOT_PUB_QUALITY} + \\"

{params.filterDat[12]}

save_plot('{output[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output[2]}', pXy, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output[3]}', pXy, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output[4]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output[5]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output[6]}', pYx, base_width=wYxPlot, base_height=hYxPlot)
save_plot('{output[7]}', pYx, base_width=wYxPlot, base_height=hYxPlot)

save_plot('{output[8]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)
save_plot('{output[9]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)


" > $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r
cat $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r | R --slave

		'''



rule aggGffCompareStats:
	input: lambda wildcards: expand(config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.stats.tsv",filtered_product_merge, techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNSplusMERGED, sizeFrac=SIZEFRACS, barcodes=BARCODESpluSMERGED, endSupport=wildcards.endSupport, minReadSupport=wildcards.minReadSupport, splicedStatus=wildcards.splicedStatus)
	output: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
echo -e "seqTech\tcorrectionLevel\tcapDesign\tsizeFrac\ttissue\tcategory\tcount" > {config[TMPDIR]}/$uuidTmpOut
cat {input} >> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule plotGffCompareStats:
	input: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.stats.tsv"
	output: returnPlotFilenames(config["PLOTSDIR"] + "tmerge.vs.gencode.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.stats")
	params:
		filterDat=lambda wildcards: merge_figures_params(wildcards.capDesign, wildcards.sizeFrac, wildcards.barcodes, wildcards.corrLevel, wildcards.techname)
	shell:
		'''
echo "
library(cowplot)
library(plyr)
library(scales)
library(gridExtra)
library(grid)
library(ggplotify)

dat <- read.table('{input}', header=T, as.is=T, sep='\\t')
{params.filterDat[10]}
{params.filterDat[0]}
{params.filterDat[1]}
{params.filterDat[2]}
{params.filterDat[3]}
{params.filterDat[4]}
{params.filterDat[5]}
{params.filterDat[8]}


dat\$category<-factor(dat\$category, ordered=TRUE, levels=rev(c('Intergenic', 'Extends', 'Intronic', 'Overlaps', 'Antisense', 'Equal', 'Included')))
palette <- c('Intergenic' = '#0099cc', 'Extends' ='#00bfff', 'Intronic' = '#4dd2ff', 'Overlaps' = '#80dfff', 'Antisense' = '#ccf2ff', 'Equal' = '#c65353', 'Included' ='#d98c8c')

plotBase <- \\"ggplot(dat[order(dat\$category), ], aes(x=factor(correctionLevel), y=count, fill=category)) +
geom_bar(stat='identity') +
scale_fill_manual(values=palette) +
ylab('# TMs') +
xlab('{params.filterDat[6]}') +
guides(fill = guide_legend(title='Category'))+
scale_y_continuous(labels=scientific)+
{params.filterDat[7]}
{GGPLOT_PUB_QUALITY} + \\"

{params.filterDat[12]}

save_plot('{output[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output[2]}', pXy, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output[3]}', pXy, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output[4]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output[5]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output[6]}', pYx, base_width=wYxPlot, base_height=hYxPlot)
save_plot('{output[7]}', pYx, base_width=wYxPlot, base_height=hYxPlot)

save_plot('{output[8]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)
save_plot('{output[9]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)


" > $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r
cat $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r | R --slave



		'''


rule getTmVsGencodeLengthStats:
	input: "mappings/nonAnchoredMergeReads/gffcompare/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.simple.tsv"
	output: config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.length.tsv"
	shell:
		'''
uuid=$(uuidgen)
file="$(dirname {input})/$(basename {input} .simple.tsv).tmap"
cat $file | awk '$3=="c" || $3=="="' | cut -f10,12 > {config[TMPDIR]}/$uuid
cat {config[TMPDIR]}/$uuid | awk -v s={wildcards.techname}Corr{wildcards.corrLevel} -v c={wildcards.capDesign} -v si={wildcards.sizeFrac} -v b={wildcards.barcodes} -v sp={wildcards.splicedStatus} '{{print s"\t"c"\t"si"\t"b"\t"sp"\t"$0}}' | sed 's/Corr0/\tNo/' | sed 's/Corr{lastK}/\tYes/' > {config[TMPDIR]}/$uuid.TmpOut
mv {config[TMPDIR]}/$uuid.TmpOut {output}

		'''

rule aggTmVsGencodeLengthStats:
	input: lambda wildcards:expand(config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.vs.gencode.length.tsv", filtered_product_merge, techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNS, sizeFrac=SIZEFRACS, barcodes=BARCODESpluSMERGED, endSupport=wildcards.endSupport, minReadSupport=wildcards.minReadSupport, splicedStatus=TMSPLICEDSTATUScategories)
	output: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.vs.gencode.length.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
echo -e "seqTech\tcorrectionLevel\tcapDesign\tsizeFrac\ttissue\tsplicingStatus\tlen\tref_match_len" > {config[TMPDIR]}/$uuidTmpOut
cat {input} >> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule plotTmVsGencodeLengthStats:
	input: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.vs.gencode.length.stats.tsv"
	output: 
		bySS=returnPlotFilenames(config["PLOTSDIR"] + "tmerge.vs.gencode.length.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:bySplicingStatus.endSupport:{endSupport}.vs.gencode.length.stats"),
		all=returnPlotFilenames(config["PLOTSDIR"] + "tmerge.vs.gencode.length.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.splicing_status:all.endSupport:{endSupport}.vs.gencode.length.stats"),

	params:
		filterDat=lambda wildcards: merge_figures_params(wildcards.capDesign, wildcards.sizeFrac, wildcards.barcodes, wildcards.corrLevel, wildcards.techname)
	shell:
		'''
echo "
library(cowplot)
library(dplyr)
library(scales)
library(gridExtra)
library(grid)
library(ggplotify)
library(ggExtra)
dat <- read.table('{input}', header=T, as.is=T, sep='\\t')
palette <- c('unspliced' = '#cc3300', 'spliced' = '#0099cc', 'all' = '#666666')
dat\$len <- as.numeric(dat\$len)
dat\$ref_match_len <- as.numeric(dat\$ref_match_len)

{params.filterDat[10]}
{params.filterDat[0]}
{params.filterDat[1]}
{params.filterDat[2]}
{params.filterDat[3]}
{params.filterDat[4]}
{params.filterDat[5]}
{params.filterDat[8]}

datAll <- subset(dat, splicingStatus=='all')

geom_textSize=geom_textSize-1
dat %>%
  group_by(splicingStatus) %>%
  summarise(n=n()) -> datSumm

summaryStats = transform(datSumm, Label = paste0('N= ', comma(n)) )

plotBase <- \\"ggplot(dat, aes(x=ref_match_len, y=len, color=splicingStatus)) + 
geom_abline(intercept=0, alpha=0.09, size=1) +
geom_point(alpha=0.1,size=0.5, stroke = 0) + 
#geom_density_2d(size=0.1, alpha=0.3) +
scale_y_log10(limits=c(100,10000)) +  
scale_x_log10(limits=c(100, 20000)) + 
geom_smooth() + 
annotate(x=100, y=10000,  label=paste('Pearson: ', round(cor(datAll\$len, datAll\$ref_match_len, method='pearson'),2)), geom='text', size=geom_textSize, color='#666666', hjust=0, vjust=1) +
annotate(x=100, y=7000,  label=paste('Spearman: ', round(cor(datAll\$len, datAll\$ref_match_len, method='spearman'),2)), geom='text', size=geom_textSize, color='#666666', hjust=0, vjust=1) +

geom_text(data = summaryStats[summaryStats\$splicingStatus=='all',], aes(label = Label, x = 100, y = 2000), hjust=0, vjust=-1,  size=geom_textSize, show.legend=FALSE) +
geom_text(data = summaryStats[summaryStats\$splicingStatus=='unspliced',], aes(label = Label, x = 100, y = 2000), hjust=0, vjust=0,  size=geom_textSize, show.legend=FALSE) +
geom_text(data = summaryStats[summaryStats\$splicingStatus=='spliced',], aes(label = Label, x = 100, y = 2000), hjust=0, vjust=1,  size=geom_textSize, show.legend=FALSE) +


guides(color = guide_legend(title='TM splicing\\nstatus'))+
xlab('Annotated length\\n(mature RNA, nts)') +
ylab('TM length\\n(mature RNA, nts)') +
scale_color_manual(values=palette) +
{GGPLOT_PUB_QUALITY} + theme(legend.position='left') \\"

plotFull <- parse(text =plotBase)
pXy <- eval(plotFull)
legend <- get_legend(pXy)
pXyNoLegend <- pXy + theme(legend.position='none')
pXyMar <- ggMarginal(pXy, groupColour = TRUE, groupFill = TRUE, xparams = list(size=0.1), yparams = list(size=0.1))
pXyMarNoLegend <- ggMarginal(pXyNoLegend, groupColour = TRUE, groupFill = TRUE, xparams = list(size=0.1), yparams = list(size=0.1))

legendOnly <- grid.arrange(legend)
pXyGrob <- as.grob(pXyMar)
pXyNoLegendGrob <- as.grob(pXyMarNoLegend)


hLegendOnly <- convertUnit(sum(legend\$heights), 'in', valueOnly=TRUE)
wLegendOnly <- convertUnit(sum(legend\$widths), 'in', valueOnly=TRUE)

hXyPlot <- plotHeight
wXyPlot <- plotWidth +2


hXyNoLegendPlot<- hXyPlot 
wXyNoLegendPlot<- wXyPlot - wLegendOnly




save_plot('{output.bySS[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output.bySS[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output.bySS[2]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output.bySS[3]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output.bySS[4]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output.bySS[5]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output.bySS[6]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output.bySS[7]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output.bySS[8]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output.bySS[9]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)





plotBase <- \\"ggplot(datAll, aes(x=ref_match_len, y=len, color=splicingStatus)) + 
geom_abline(intercept=0, alpha=0.09, size=1) +
geom_point(alpha=0.1,size=0.5, stroke = 0) + 
#geom_density_2d(size=0.1, alpha=0.3) +
scale_y_log10(limits=c(100,10000)) +  
scale_x_log10(limits=c(100, 20000)) + 
geom_smooth() + 
annotate(x=100, y=10000,  label=paste('Pearson: ', round(cor(datAll\$len, datAll\$ref_match_len, method='pearson'),2)), geom='text', size=geom_textSize, color='#666666', hjust=0, vjust=1) +
annotate(x=100, y=7000,  label=paste('Spearman: ', round(cor(datAll\$len, datAll\$ref_match_len, method='spearman'),2)), geom='text', size=geom_textSize, color='#666666', hjust=0, vjust=1) +
geom_text(data = summaryStats[summaryStats\$splicingStatus=='all',], aes(label = Label, x = 100, y = 2000), hjust=0, vjust=-1,  size=geom_textSize, show.legend=FALSE) +

guides(color = guide_legend(title='TM splicing\\nstatus'))+
xlab('Annotated length\\n(mature RNA, nts)') +
ylab('TM length\\n(mature RNA, nts)') +
scale_color_manual(values=palette) +
{GGPLOT_PUB_QUALITY} + theme(legend.position='left') \\"

plotFull <- parse(text =plotBase)
pXy <- eval(plotFull)
legend <- get_legend(pXy)
pXyNoLegend <- pXy + theme(legend.position='none')
pXyMar <- ggMarginal(pXy, groupColour = TRUE, groupFill = TRUE, xparams = list(size=0.1), yparams = list(size=0.1))
pXyMarNoLegend <- ggMarginal(pXyNoLegend, groupColour = TRUE, groupFill = TRUE, xparams = list(size=0.1), yparams = list(size=0.1))

legendOnly <- grid.arrange(legend)
pXyGrob <- as.grob(pXyMar)
pXyNoLegendGrob <- as.grob(pXyMarNoLegend)


hLegendOnly <- convertUnit(sum(legend\$heights), 'in', valueOnly=TRUE)
wLegendOnly <- convertUnit(sum(legend\$widths), 'in', valueOnly=TRUE)

hXyPlot <- plotHeight
wXyPlot <- plotWidth +2


hXyNoLegendPlot<- hXyPlot 
wXyNoLegendPlot<- wXyPlot - wLegendOnly




save_plot('{output.all[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output.all[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output.all[2]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output.all[3]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output.all[4]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output.all[5]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output.all[6]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output.all[7]}', pXyMar, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output.all[8]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output.all[9]}', pXyMarNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)


" > $(dirname {output.all[0]})/$(basename {output[0]} .legendOnly.png).r
cat $(dirname {output.all[0]})/$(basename {output[0]} .legendOnly.png).r | R --slave

		'''

rule simplifyGencode:
	input: lambda wildcards: CAPDESIGNTOANNOTGTF[wildcards.capDesign]
	output: "annotations/simplified/{capDesign}.gencode.simplified_biotypes.gtf"
	shell:
		'''
uuidTmpOut=$(uuidgen)
cat {input}  | simplifyGencodeGeneTypes.pl - | sort -T {config[TMPDIR]}  -k1,1 -k4,4n -k5,5n  > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule mergeTmsWithGencode:
	input:
		annot="annotations/simplified/{capDesign}.gencode.simplified_biotypes.gtf",
		tm="mappings/nonAnchoredMergeReads/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.splicing_status:all.endSupport:{endSupport}.gff"
	output: "mappings/nonAnchoredMergeReads/gencodeMerge/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.+gencode.gff.gz"
	threads:1
	shell:
		'''
uuidTmpOut=$(uuidgen)
cat {input.annot} {input.tm}  | skipcomments | sort -T {config[TMPDIR]}  -k1,1 -k4,4n -k5,5n  | tmerge --exonOverhangTolerance {config[exonOverhangTolerance]} - |sort -T {config[TMPDIR]}  -k1,1 -k4,4n -k5,5n  |gzip > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule makeClsGencodeLoci:
	input: "mappings/nonAnchoredMergeReads/gencodeMerge/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.+gencode.gff.gz"
	params: locusPrefix=config["PROJECT_NAME"]
	output: temp("mappings/nonAnchoredMergeReads/gencodeLociMerge/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.+gencode.loci.gff.gz")
	shell:
		'''
uuid=$(uuidgen)
uuidTmpOut=$(uuidgen)
zcat {input} > {config[TMPDIR]}/$uuid
bedtools intersect -s -wao -a {config[TMPDIR]}/$uuid -b {config[TMPDIR]}/$uuid |fgrep -v ERCC| buildLoci.pl --locPrefix {params.locusPrefix}: - |sort -T {config[TMPDIR]}  -k1,1 -k4,4n -k5,5n  | gzip> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''


rule mergeWithRef:
	input:
		clsGencode="mappings/nonAnchoredMergeReads/gencodeLociMerge/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.+gencode.loci.gff.gz",
		gencode="annotations/simplified/{capDesign}.gencode.simplified_biotypes.gtf"
	output: "mappings/nonAnchoredMergeReads/mergeToRef/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.+gencode.loci.refmerged.gff.gz"
	shell:
		'''
uuid=$(uuidgen)
uuidTmpOut=$(uuidgen)
zcat  {input.clsGencode} > {config[TMPDIR]}/$uuid
mergeToRef.pl {input.gencode} {config[TMPDIR]}/$uuid | sort -T {config[TMPDIR]}  -k1,1 -k4,4n -k5,5n  |gzip > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule getNovelIntergenicLoci:
	input:
		gencode="annotations/simplified/{capDesign}.gencode.simplified_biotypes.gtf",
		tmergeGencode="mappings/nonAnchoredMergeReads/mergeToRef/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.+gencode.loci.refmerged.gff.gz"
	output:"mappings/nonAnchoredMergeReads/mergeToRef/novelLoci/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.novelLoci.gff.gz"
	shell:
		'''
uuid1=$(uuidgen)
uuid2=$(uuidgen)
uuid3=$(uuidgen)
uuid4=$(uuidgen)
uuid5=$(uuidgen)
uuidTmpOut=$(uuidgen)
cat {input.gencode} |awk '$3=="exon"' | extract_locus_coords.pl -| sort -T {config[TMPDIR]}  -k1,1 -k2,2n -k3,3n  > {config[TMPDIR]}/$uuid1
zcat {input.tmergeGencode} | tgrep -F 'gene_ref_status "novel";' > {config[TMPDIR]}/$uuid4
cat {config[TMPDIR]}/$uuid4 | extract_locus_coords.pl - | sort -T {config[TMPDIR]}  -k1,1 -k2,2n -k3,3n  > {config[TMPDIR]}/$uuid2
bedtools intersect -v -a {config[TMPDIR]}/$uuid2 -b {config[TMPDIR]}/$uuid1 > {config[TMPDIR]}/$uuid5
cat {config[TMPDIR]}/$uuid5 |tgrep -F -v ERCC |cut -f4 | sort -T {config[TMPDIR]} |uniq > {config[TMPDIR]}/$uuid3
zcat {input.tmergeGencode}| tgrep -F -w -f {config[TMPDIR]}/$uuid3 - |gzip > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''

rule getNovelIntergenicLociStats:
	input:
		tmergeGencode="mappings/nonAnchoredMergeReads/mergeToRef/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.+gencode.loci.refmerged.gff.gz",
		intergenic="mappings/nonAnchoredMergeReads/mergeToRef/novelLoci/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.novelLoci.gff.gz"
	output: config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.novelLoci.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
totalNovel=$(zcat {input.tmergeGencode} | tgrep -F 'gene_ref_status "novel";' |extractGffAttributeValue.pl gene_id | sort -T {config[TMPDIR]} | uniq | wc -l)
interg=$(zcat {input.intergenic} | extractGffAttributeValue.pl gene_id | sort -T {config[TMPDIR]} | uniq | wc -l)
echo -e "{wildcards.techname}Corr{wildcards.corrLevel}\t{wildcards.capDesign}\t{wildcards.sizeFrac}\t{wildcards.barcodes}\t$totalNovel\t$interg"  > {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}

		'''

rule aggNovelIntergenicLociStats:
	input: lambda wildcards: expand(config["STATSDATADIR"] + "tmp/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.novelLoci.stats.tsv",filtered_product_merge, techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=CAPDESIGNSplusMERGED, sizeFrac=SIZEFRACS, barcodes=BARCODESpluSMERGED, endSupport=wildcards.endSupport, minReadSupport=wildcards.minReadSupport)
	output: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.novelLoci.stats.tsv"
	shell:
		'''
uuidTmpOut=$(uuidgen)
echo -e "seqTech\tcorrectionLevel\tcapDesign\tsizeFrac\ttissue\tcategory\tcount\tpercent" > {config[TMPDIR]}/$uuidTmpOut
cat {input} | awk '{{if ($5!=0) print $1"\\t"$2"\\t"$3"\\t"$4"\\tintergenic\\t"$6"\\t"$6/$5"\\n"$1"\\t"$2"\\t"$3"\\t"$4"\\tintronic\\t"$5-$6"\\t"($5-$6)/$5; else print $1"\\t"$2"\\t"$3"\\t"$4"\\tintergenic\\t"$6"\\t0\\n"$1"\\t"$2"\\t"$3"\\t"$4"\\tintronic\\t"$5-$6"\\t0"}}'| sed 's/Corr0/\tNo/' | sed 's/Corr{lastK}/\tYes/' | sort -T {config[TMPDIR]}  >> {config[TMPDIR]}/$uuidTmpOut
mv {config[TMPDIR]}/$uuidTmpOut {output}
		'''


rule plotNovelIntergenicLociStats:
	input: config["STATSDATADIR"] + "all.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.novelLoci.stats.tsv"
	output: returnPlotFilenames(config["PLOTSDIR"] + "tmerge.novelLoci.stats/{techname}/Corr{corrLevel}/{capDesign}/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.tmerge.min{minReadSupport}reads.endSupport:{endSupport}.novelLoci.stats")
	params:
		filterDat=lambda wildcards: merge_figures_params(wildcards.capDesign, wildcards.sizeFrac, wildcards.barcodes, wildcards.corrLevel, wildcards.techname)
	shell:
		'''
echo "
library(cowplot)
library(plyr)
library(scales)
library(gridExtra)
library(grid)
library(ggplotify)

dat <- read.table('{input}', header=T, as.is=T, sep='\\t')
{params.filterDat[10]}
{params.filterDat[0]}
{params.filterDat[1]}
{params.filterDat[2]}
{params.filterDat[3]}
{params.filterDat[4]}
{params.filterDat[5]}
{params.filterDat[8]}

dat\$category<-factor(dat\$category, ordered=TRUE, levels=rev(c('intronic', 'intergenic')))
plotBase <- \\"ggplot(dat[order(dat\$category), ], aes(x=factor(correctionLevel), y=count, fill=category)) +
geom_bar(stat='identity') +
ylab('# Novel CLS loci') +
scale_y_continuous(labels=comma)+
scale_fill_manual (values=c(intronic='#d98c8c', intergenic='#33ccff'))+
xlab('{params.filterDat[6]}') +
guides(fill = guide_legend(title='Category\\n(w.r.t. GENCODE)'))+
geom_text(position = 'stack', size=geom_textSize, aes(x = factor(correctionLevel), y = count, label = paste(sep='',percent(round(percent, digits=2)),' / ','(',comma(count),')'), hjust = 0.5, vjust = 1))+
{params.filterDat[7]}
{GGPLOT_PUB_QUALITY}  + \\"

{params.filterDat[12]}

save_plot('{output[0]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)
save_plot('{output[1]}', legendOnly, base_width=wLegendOnly, base_height=hLegendOnly)

save_plot('{output[2]}', pXy, base_width=wXyPlot, base_height=hXyPlot)
save_plot('{output[3]}', pXy, base_width=wXyPlot, base_height=hXyPlot)

save_plot('{output[4]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)
save_plot('{output[5]}', pXyNoLegend, base_width=wXyNoLegendPlot, base_height=hXyNoLegendPlot)

save_plot('{output[6]}', pYx, base_width=wYxPlot, base_height=hYxPlot)
save_plot('{output[7]}', pYx, base_width=wYxPlot, base_height=hYxPlot)

save_plot('{output[8]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)
save_plot('{output[9]}', pYxNoLegend, base_width=wYxNoLegendPlot, base_height=hYxNoLegendPlot)


" > $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r
cat $(dirname {output[0]})/$(basename {output[0]} .legendOnly.png).r | R --slave



		'''



rule tmergeAll:
	input:
		tm=lambda wildcards: expand("mappings/nonAnchoredMergeReads/{techname}Corr{corrLevel}_{capDesign}_{sizeFrac}_{barcodes}.HiSS.tmerge.min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.gff", filtered_product_merge, techname=TECHNAMES, corrLevel=FINALCORRECTIONLEVELS, capDesign=wildcards.capDesign, sizeFrac=SIZEFRACSnoSIZESELECTONLY, barcodes=BARCODES, endSupport=wildcards.endSupport,  minReadSupport=wildcards.minReadSupport, splicedStatus=wildcards.splicedStatus)
		#gencode="annotations/simplified/{capDesign}.gencode.simplified_biotypes.gtf",
	output: 
		tm="mappings/nonAnchoredMergeReads/tmergeAll/{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.tmerge.gff",
		quant="mappings/nonAnchoredMergeReads/tmergeAll/{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.tmerge.expQuant.tsv"
	shell:
		'''
uuid=$(uuidgen)
uuidTmpOutT=$(uuidgen)
uuidTmpOutQ=$(uuidgen)
for file in `ls {input.tm} | grep -v AlzhBrain`; do
bn=$(basename $file .HiSS.tmerge.min{wildcards.minReadSupport}reads.splicing_status:{wildcards.splicedStatus}.endSupport:{wildcards.endSupport}.gff | sed 's/Corr0_/_/g')

cat $file | perl -sne '$_=~s/transcript_id \"(\S+)\"/transcript_id \"=$var=$1\"/g; print' -- -var=$bn
done > {config[TMPDIR]}/$uuid
echo -e "transcript_id\tspliced\tflrpm\trpm" > {config[TMPDIR]}/$uuidTmpOutQ
cat {config[TMPDIR]}/$uuid | extractGffAttributeValue.pl transcript_id spliced flrpm rpm | sort|uniq >> {config[TMPDIR]}/$uuidTmpOutQ
countDups=$(cat {config[TMPDIR]}/$uuidTmpOutQ |cut -f1 |sort|uniq -d |wc -l)
if [ $countDups -gt 0 ]; then echoerr "$countDups duplicates found"; exit 1; fi;
cat {config[TMPDIR]}/$uuid  | skipcomments | sort -T {config[TMPDIR]} -k1,1 -k4,4n -k5,5n | tmerge --exonOverhangTolerance {config[exonOverhangTolerance]} - |sort -T {config[TMPDIR]}  -k1,1 -k4,4n -k5,5n  > {config[TMPDIR]}/$uuidTmpOutT
mv {config[TMPDIR]}/$uuidTmpOutT {output.tm}
mv {config[TMPDIR]}/$uuidTmpOutQ {output.quant}

		'''

rule getSampleComparisonStats:
	input: "mappings/nonAnchoredMergeReads/tmergeAll/{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.tmerge.gff"
	output: 
		fullMatrix=config["STATSDATADIR"] + "all.sampleComparison.{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.stats.tsv",
		simpsonMatrix=config["STATSDATADIR"] + "all.sampleComparison.{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.overlap_coeff.tsv",
		jaccardMatrix=config["STATSDATADIR"] + "all.sampleComparison.{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.jaccard_ind.tsv",
		OneMinusSimpsonMatrix=config["STATSDATADIR"] + "all.sampleComparison.{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.oneMinusSimpson_coeff.tsv",
		OneMinusJaccardMatrix=config["STATSDATADIR"] + "all.sampleComparison.{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.oneMinusJaccard_coeff.tsv"
	shell:
		'''
cat {input} | tmergeToBinaryMatrix.pl - $(dirname {output.simpsonMatrix})/$(basename {output.simpsonMatrix} .overlap_coeff.tsv) |perl -ne '$_=~s/(\S+):Corr\d+_(\S+)/$1 $2/g; print' > {output.fullMatrix}

#convert simpson matrix to dissimilarity matrix (1-simpson)
 cat {output.simpsonMatrix} |perl -ne 'chomp; @line=split "\\t"; for($i=0; $i<=$#line;$i++){{$t=$line[$i];if ($t=~/^-?(?:\d+\.?|\.\d)\d*\z/ ){{$line[$i]=1-$line[$i]}}}}; print join("\\t", @line)."\\n"' > {output.OneMinusSimpsonMatrix}
 cat {output.jaccardMatrix} |perl -ne 'chomp; @line=split "\\t"; for($i=0; $i<=$#line;$i++){{$t=$line[$i];if ($t=~/^-?(?:\d+\.?|\.\d)\d*\z/ ){{$line[$i]=1-$line[$i]}}}}; print join("\\t", @line)."\\n"' > {output.OneMinusJaccardMatrix}

		'''

rule plotSampleComparisonStats:
	input: 
		simpson=config["STATSDATADIR"] + "all.sampleComparison.{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.overlap_coeff.tsv",
		jaccard=config["STATSDATADIR"] + "all.sampleComparison.{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.jaccard_ind.tsv",

	output: 
		simpson=config["PLOTSDIR"] + "sampleComparison.stats/{capDesign}/{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.heatmap.sampleComparison.simpson.png",
		jaccard=config["PLOTSDIR"] + "sampleComparison.stats/{capDesign}/{capDesign}_min{minReadSupport}reads.splicing_status:{splicedStatus}.endSupport:{endSupport}.heatmap.sampleComparison.jaccard.png"
	shell:
		'''
echo "
library(cluster)
library(pheatmap)
library(tidyverse)
library(RColorBrewer)
library(viridis)

dat <- read.table('{input.simpson}', header=T, as.is=T, sep='\t', row.names=1)
annot <- read.table('{config[SAMPLE_ANNOT]}', header=T, as.is=T, sep='\t')
annotSumm <- annot %>% select(sample_name, seqTech, libraryPrep, tissue)
annotSumm <- column_to_rownames(annotSumm, 'sample_name')
#simBreaks <- c(0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1)
#pheatmap(dat,clustering_method='ward.D2', color = inferno(length(simBreaks) - 1), breaks = simBreaks, treeheight_col=0, annotation_row = annotSumm, filename='{output.simpson}', width=6, height=4,fontsize_row=4, fontsize_col=4)
pheatmap(dat,clustering_method='ward.D2', color = inferno(50), treeheight_col=10, annotation_row = annotSumm, filename='{output.simpson}', width=6, height=4,fontsize_row=4, fontsize_col=4)

" > {output.simpson}.r
cat {output.simpson}.r | R --slave

echo "
library(cluster)
library(pheatmap)
library(tidyverse)
library(RColorBrewer)
library(viridis)

dat <- read.table('{input.jaccard}', header=T, as.is=T, sep='\t', row.names=1)
annot <- read.table('{config[SAMPLE_ANNOT]}', header=T, as.is=T, sep='\t')
annotSumm <- annot %>% select(sample_name, seqTech, libraryPrep, tissue)
annotSumm <- column_to_rownames(annotSumm, 'sample_name')
#simBreaks <- c(0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1)
#pheatmap(dat,clustering_method='ward.D2', color = inferno(length(simBreaks) - 1), breaks = simBreaks, treeheight_col=0, annotation_row = annotSumm, filename='{output.jaccard}', width=6, height=4,fontsize_row=4, fontsize_col=4)
pheatmap(dat,clustering_method='ward.D2', color = inferno(50), treeheight_col=10, annotation_row = annotSumm, filename='{output.jaccard}', width=6, height=4,fontsize_row=4, fontsize_col=4)


" > {output.jaccard}.r
cat {output.jaccard}.r | R --slave

		'''
