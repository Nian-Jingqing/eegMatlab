function [output, pcaResult] = imputeUsingPpca(input, maxMemory)


%error checking
if(size(input, 1) < size(input, 2))
    error('number of observations (rows) should be larger than the number of variables (columns)');
end


%figure out max components based on available memory
if(~exist('maxMemory', 'var'))
    [memInfo, memSys] = memory();    
    %maxMemory = memInfo.MaxPossibleArrayBytes;
    maxMemory = memSys.PhysicalMemory.Available;
end
%maxComponents = floor(sqrt(maxMemory / size(input,1) / 8));

componentCount = size(input, 2);
maxSamples = floor(maxMemory / (componentCount * componentCount * 8));
downsampleRate = ceil(size(input, 1) / maxSamples);

% if(maxComponents >= componentCount)
%     fprintf('imputing with all %d available components', componentCount);
% else
%     componentCount = maxComponents;
%     fprintf('trimming to %d components to conserve memory', componentCount);
% end

if(downsampleRate > 1)
     fprintf('imputing with all %d observations\n', size(input, 1));
else
    oldSize = size(input,1);
    input = downsample(input, downsampleRate);
    fprintf('downsapmling to %d observations (%0.1f%%) based on available physical memory (%0.2f GB)\n', size(input, 1), size(input,1) / oldSize * 100, maxMemory / 1024  / 1024  / 1024);
end


%impute using mean values to produce a starting point for nan
meanedInput = input;
for i = 1:size(meanedInput, 2)
    nans = isnan(meanedInput(:,i));
    meanValue = mean(meanedInput(~nans, i));
    meanedInput(nans, i) = meanValue;
end
[pcaResult0.COEFF,pcaResult0.SCORE,pcaResult0.LATENT,pcaResult0.MU,pcaResult0.V,pcaResult0.S] = pca(meanedInput, 'NumComponents', componentCount);


ppcaOptions.Display = 'iter';
ppcaOptions.MaxIter = 500;
ppcaOptions.TolFun = 1e-6;
ppcaOptions.TolX = 1e-6;

tic;
[pcaResult.COEFF,pcaResult.SCORE,pcaResult.LATENT,pcaResult.MU,pcaResult.V,pcaResult.S] = ppcaQuicker(input, componentCount, 'W0', pcaResult0.COEFF, 'Options', ppcaOptions);
pcaResult.elapsedSeconds = toc;
pcaResult.maxComponennts = componentCount;

%check for nans in score
if(false)
    scoreNanInd = find(isnan(pcaResult.SCORE));
    scoreNanCoord(:,1) = ceil(scoreNanInd ./ size(pcaResult.SCORE,1))
    scoreNanCoord(:,2) = ceil(mod(scoreNanInd, size(pcaResult.SCORE,1)))
    [scoreNanRow, scoreNanCol] = ind2sub(size(pcaResult.SCORE), scoreNanInd);
end


%reconstruct missing dataset and compare to known values
reconstructed = pcaResult.SCORE * pcaResult.COEFF';
output = input;
for i = 1:size(input, 2)
    meanValue = nanmean(input(:, i));
    reconstructed(:, i) = reconstructed(:, i) + meanValue;
    realMeasure = ~isnan(input(:, i));
    [rhos(i), ps(i)] = corr(input(realMeasure, i), reconstructed(realMeasure, i));
    output(~realMeasure, i) = reconstructed(~realMeasure, i);
end
pcaResult.correlations = rhos;
% meanRho = mean(abs(rhos));

if(false)
    %plot a characteristically missing variable
    missingCount = sum(isnan(input));
    ind = find(missingCount == max(missingCount))
    indMin = find(missingCount == min(missingCount))
    column = ind(1);
    toPlot = [input(:, column), output(:, column)];
    figure;
    plot(toPlot);
    legend('actual', 'predicted');
end

% save('C:\Users\Neuro\Documents\MATLAB\processed\GhermanPhilastides\imputedByPpca.mat', 'pcaResult', '-v7.3');
% 
% save('C:\Users\Neuro\Documents\MATLAB\processed\GhermanPhilastides\imputed.mat', '-v7.3');
