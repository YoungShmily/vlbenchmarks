function reproduceKm()
% BENCHMARKDEMO Script demonstrating how to run the benchmarks for
%   different algorithms.
%

%% Define Local features detectors

import localFeatures.*;

descDet = vggAffine();

detectors{1} = vggAffine('Detector', 'haraff','Threshold',1000);
detectors{2} = vggAffine('Detector', 'hesaff','Threshold',500);
detectors{3} = descriptorAdapter(vggMser('es',2),descDet);
detectors{4} = descriptorAdapter(ibr('ScaleFactor',1),descDet);
detectors{5} = descriptorAdapter(ebr(),descDet);

detNames = {'Harris-Affine','Hessian-Affine','MSER','IBR','EBR'};
numDetectors = numel(detectors);


%% Define benchmarks

import benchmarks.*;

repBenchmark = repeatabilityBenchmark(...
  'MatchFramesGeometry',true,...
  'MatchFramesDescriptors',false,...
  'WarpMethod','km',...
  'CropFrames',true,...
  'NormaliseFrames',true,...
  'OverlapError',0.4);
matchBenchmark = repeatabilityBenchmark(...
  'MatchFramesGeometry',true,...
  'MatchFramesDescriptors',true,...
  'WarpMethod','km',...
  'CropFrames',true,...
  'NormaliseFrames',true,...
  'OverlapError',0.4);

kmBenchmark = kristianEvalBenchmark('CommonPart',1);

%% Define Figure
fig = figure('Visible','off');

%% Define dataset

import datasets.*;

categories = vggAffineDataset.allCategories;
datasetNum = 1;
resultsDir = 'ijcv05_res';

%% Repeatability vs. overlap error

confFig(fig);
dataset = vggAffineDataset('category','graf');
overlapErrs = 0.1:0.1:0.6;
imageBIdx = 4;
overlapReps = zeros(numDetectors,numel(overlapErrs));
for oei = 1:numel(overlapErrs)
  rBenchm = repeatabilityBenchmark(...
  'MatchFramesGeometry',true,...
  'MatchFramesDescriptors',false,...
  'WarpMethod','km',...
  'CropFrames',true,...
  'NormaliseFrames',true,...
  'OverlapError',overlapErrs(oei));

  imageAPath = dataset.getImagePath(1);
  imageBPath = dataset.getImagePath(imageBIdx);
  H = dataset.getTransformation(imageBIdx);
  for detectorIdx = 1:numDetectors
    detector = detectors{detectorIdx};
    [overlapReps(detectorIdx,oei) tmp] = ...
      rBenchm.testDetector(detector, H, imageAPath,imageBPath);
  end
end

saveResults(overlapReps, fullfile(resultsDir,'rep_vs_overlap'));
subplot(2,2,1); 
plot(overlapErrs.*100,overlapReps.*100); grid on;
xlabel('Overlap error %'); ylabel('Repeatability %');
axis([5 65 0 100]);
legend(detNames,'Location','NorthWest');

%% Repeatability vs. region size

regSizes = [15 30 50 75 90 110];
regSizeReps = zeros(numDetectors,size(regSizes));
for rsi = 1:numel(regSizes)
  rBenchm = repeatabilityBenchmark(...
  'MatchFramesGeometry',true,...
  'MatchFramesDescriptors',false,...
  'WarpMethod','km',...
  'CropFrames',true,...
  'NormaliseFrames',true,...
  'OverlapError',0.4,...
  'NormalisedScale',regSizes(rsi));
  imageAPath = dataset.getImagePath(1);
  imageBPath = dataset.getImagePath(imageBIdx);
  H = dataset.getTransformation(imageBIdx);
  for detectorIdx = 1:numDetectors
    detector = detectors{detectorIdx};
    [regSizeReps(detectorIdx,rsi) tmp] = ...
      rBenchm.testDetector(detector, H, imageAPath,imageBPath);
  end
end
saveResults(overlapReps, fullfile(resultsDir,'rep_vs_norm_reg_size'));
subplot(2,2,2); 
plot(regSizes,regSizeReps.*100); grid on;
xlabel('Normalised region size'); ylabel('Repeatability %');
axis([10 120 0 100]);
legend(detNames,'Location','SouthEast');

%% Regions sizes histograms
numFrames = cell(1,numDetectors);
runTime = cell(1,numDetectors);
dataset = vggAffineDataset('category','graf');

confFig(fig);

for di = 1:numDetectors
  refImgPath = dataset.getImagePath(1);
  % Removed cached data in order to force compuation
  detectors{di}.disableCaching();
  startTime = tic;
  frames = detectors{di}.extractFeatures(refImgPath);
  runTime{di} = toc(startTime);
  detectors{di}.enableCaching();
  numFrames{di} = size(frames,2);
  scales = getFrameScale(frames);
  subplot(2,3,di);
  scalesHist = hist(scales,0:100);
  bar(scalesHist);
  axis([0 100 0 ceil(max(scalesHist)/10)*10]); 
  grid on;
  title(detNames{di});
  xlabel('Average region size');
  ylabel('Number of detected regions');
end

print(fig,fullfile(resultsDir, ['fig' num2str(datasetNum) '_rm_' ...
  dataset.category '.eps']),'-depsc');

%% Repeatability / Matching scores

for category=categories
  fprintf('\n######## TESTING DATASET %s #######\n',category{:});
  dataset = vggAffineDataset('category',category{:});

  %% Run the new benchmarks in parallel
  numImages = dataset.numImages;

  repeatability = zeros(numDetectors, numImages);
  numCorresp = zeros(numDetectors, numImages);

  matchingScore = zeros(numDetectors, numImages);
  numMatches = zeros(numDetectors, numImages);

  % Test all detectors
  for detectorIdx = 1:numDetectors
    detector = detectors{detectorIdx};
    imageAPath = dataset.getImagePath(1);
    parfor imageIdx = 2:numImages
      imageBPath = dataset.getImagePath(imageIdx);
      H = dataset.getTransformation(imageIdx);
      [repeatability(detectorIdx,imageIdx) numCorresp(detectorIdx,imageIdx)] = ...
        repBenchmark.testDetector(detector, H, imageAPath,imageBPath);
      [matchingScore(detectorIdx,imageIdx) numMatches(detectorIdx,imageIdx)] = ...
        matchBenchmark.testDetector(detector, H, imageAPath,imageBPath);
    end
  end



  %% Show scores

  confFig(fig);
  titleText = ['Detectors Repeatability [%%] (',category,')'];
  printScores(repeatability.*100, detNames, titleText,fullfile(resultsDir,[category '_rep']));
  subplot(2,2,1); plotScores(repeatability.*100, detNames, dataset, titleText);

  printScores(repeatability.*100, detNames, titleText,fullfile(resultsDir,[category '_rep']));
  subplot(2,2,1); plotScores(repeatability.*100, detNames, dataset, titleText);

  titleText = ['Detectors Num. Correspondences (',category,')'];
  printScores(numCorresp, detNames, titleText,fullfile(resultsDir,[category '_ncorresp']));
  subplot(2,2,2); plotScores(numCorresp, detNames, dataset, titleText);

  titleText = ['Detectors Matching Score [%%] (',category,')'];
  printScores(matchingScore.*100, detNames, titleText,fullfile(resultsDir,[category '_matching']));
  subplot(2,2,3); plotScores(matchingScore.*100, detNames, dataset, titleText);

  titleText = ['Detectors Num. Matches (',category,')'];
  printScores(numMatches, detNames, titleText,fullfile(resultsDir,[category '_nmatches']));
  subplot(2,2,4); plotScores(numMatches, detNames, dataset, titleText);

  print(fig,fullfile(resultsDir, ['fig' num2str(datasetNum) '_rm_' ...
    dataset.category '.eps']),'-depsc');

  %% For comparison, run KM Benchmark

  % Test all detectors
  for detectorIdx = 1:numDetectors
    detector = detectors{detectorIdx};
    imageAPath = dataset.getImagePath(1);
    parfor imageIdx = 2:numImages
      imageBPath = dataset.getImagePath(imageIdx);
      H = dataset.getTransformation(imageIdx);
      [repeatability(detectorIdx,imageIdx) numCorresp(detectorIdx,imageIdx)] = ...
        kmBenchmark.testDetector(detector, H, imageAPath,imageBPath);
      [tmp tmp2 matchingScore(detectorIdx,imageIdx) numMatches(detectorIdx,imageIdx)] = ...
        kmBenchmark.testDetector(detector, H, imageAPath,imageBPath);
    end
  end

  %%

  confFig(fig);

  titleText = 'Detectors Repeatability [%%]';
  printScores(repeatability.*100, detNames, titleText,fullfile(resultsDir,['km_' category '_rep']));
  subplot(2,2,1); plotScores(repeatability.*100, detNames, dataset, titleText);

  titleText = ['KM Detectors Num. Correspondences (',category,')'];
  printScores(numCorresp, detNames, titleText,fullfile(resultsDir,['km_' category '_ncorresp']));
  subplot(2,2,2); plotScores(numCorresp, detNames, dataset, titleText);

  titleText = ['KM Detectors Matching Score [%%] (',category,')'];
  printScores(matchingScore.*100, detNames, titleText,fullfile(resultsDir,['km_' category '_matching']));
  subplot(2,2,3); plotScores(matchingScore.*100, detNames, dataset, titleText);

  titleText = ['KM Detectors Num. Matches (',category,')'];
  printScores(numMatches, detNames, titleText,fullfile(resultsDir,['km_' category '_nmatches']));
  subplot(2,2,4); plotScores(numMatches, detNames, dataset, titleText);

  print(fig,fullfile(resultsDir, ['fig' num2str(datasetNum) '_rm_' ...
    dataset.category '.eps']),'-depsc');

  datasetNum = datasetNum + 1;
end

%% Helper functions

function printScores(scores, scoreLineNames, name, fileName)
  % PRINTSCORES
  numScores = numel(scoreLineNames);

  maxNameLen = 0;
  for k = 1:numScores
    maxNameLen = max(maxNameLen,length(scoreLineNames{k}));
  end

  maxNameLen = max(length('Method name'),maxNameLen);
  fprintf(['\n', name,':\n']);
  formatString = ['%' sprintf('%d',maxNameLen) 's:'];

  fprintf(formatString,'Method name');
  for k = 1:size(scores,2)
    fprintf('\tImg#%02d',k);
  end
  fprintf('\n');

  for k = 1:numScores
    fprintf(formatString,scoreLineNames{k});
    for l = 2:size(scores,2)
      fprintf('\t%6s',sprintf('%.2f',scores(k,l)));
    end
    fprintf('\n');
  end
  
  if exist('fileName','var');
    saveResults(scores,fileName);
  end
end

function saveResults(scores, fileName)
  [dir name] = fileparts(fileName);
  vl_xmkdir(dir);
  save(fullfile(dir,name),'scores');
  csvwrite(fullfile(dir, [name '.csv']), scores);
end

function plotScores(scores, detNames, dataset, titleText)
  % PLOTSCORES
  import helpres.*;
  titleText = sprintf(titleText);
  
  xLabel = dataset.imageNamesLabel;
  xVals = dataset.imageNames;
  plot(xVals,scores(:,2:6)','linewidth', 1) ; hold on ;
  ylabel(titleText) ;
  xlabel(xLabel);
  title(titleText);

  maxScore = ceil(max([max(max(scores)) 100])/10)*10;

  legend(detNames,'Location','NorthEast');
  grid on ;
  axis([min(xVals)*0.9 max(xVals)*1.05 0 maxScore]);
end

function scale = getFrameScale(frames)
  det = prod(frames([3 5],:)) - frames(4,:).^2;
  scale = sqrt(sqrt(det));
end

function confFig(fig)
  clf(fig);
  set(fig,'PaperPositionMode','auto')
  set(fig,'PaperType','A4');
  set(fig, 'Position', [0, 0, 900,700]);
end

end
