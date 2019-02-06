clear;

createDummyFile = true;

doPhaseAngle = true;
simOnly = false;
summaryOnly = false;


sampleRate = 2048;
epochLength = 1 * sampleRate;
chan1 = 100;
startIndex = (chan1-1) * epochLength + 1;
endIndex = startIndex + epochLength - 1;

hiPassHz = 1;
loPassHz = 40;

% filenames = [{'/home/data/EEG/data/ROBI/ROBI_003/baseline eyes open/630158995692243270.eegData'}, ...
%   {'/home/data/EEG/data/ROBI/ROBI_003/outcome eyes open/630230539149591228.eegData'}];

%filename = '/Users/Geoff/Documents/MATLAB/EEG/Coe Collection/Robi/ROBI_003/tx 1/630165006453007385.eegData';
%        filename = '/home/data/EEG/data/ROBI/ROBI_003/outcome eyes open/630230539149591228.eegData';

filenames = getRobiDataFiles();

for fileCounter = 1:length(filenames)
  filename = filenames{fileCounter};
  if(summaryOnly)
    outputFolder = '/home/data/EEG/processed/Robi/coherenceReref';
  else
    outputFolder = '/home/data/EEG/processed/Robi/coherence';
    oldFolder = pwd;
    outputFolder = '/media/eegDrive';    
    cd(outputFolder);  %just testing permissions
    cd(oldFolder);
  end
  outputStart = strfind(filename, 'ROBI_');
  if(length(outputStart) < 1)
    error('invalid filename');
  end
  outFile = filename(outputStart(1):end);
  outFile = strrep(outFile,'/','_');
  outFile = strrep(outFile,'.eegData','coherenceStats.mat');
  outputPath = fullfile(outputFolder, outFile);
  if(~exist(outputPath, 'file'))
    if(createDummyFile)
      dummy = sprintf('started on %s', char(datetime));
      save(outputPath, 'dummy');
    end
    
    channelCount = 34;
    file = dir(filename);
    fileLength = file.bytes / 8;
    fileId = fopen(filename);    
    contents = fread(fileId, fileLength, 'double');    
    fclose(fileId);
    
    %truncate if necessary
    sampleCount = fileLength / channelCount;
    if(sampleCount ~= floor(sampleCount))
      sampleCount = floor(sampleCount);
      fileLength = sampleCount * channelCount;
      contents = contents(1:fileLength);
    end
    
    
    
    labels = antChannelLocs;
    
    data = reshape(contents, channelCount, fileLength / channelCount)';
    clear contents;
    
    cpzIndex = find(strcmp(labels,'CPz'));
    m1Index = find(strcmp(labels,'M1'));
    m2Index = find(strcmp(labels,'M2'));
    
    for i=1:size(data,1)
      sample = data(i,:);
      linkedMastoids = (sample(m1Index) + sample(m2Index)) / 2;
      avg = mean(sample(1:33));
      newSample = sample - linkedMastoids;
      avgSample = sample - avg;
      data(i,1:33) = newSample(1:33);      
    end

    
    maxPairs = 0;
    indexTable = [];
    pairLabels = cell(0);
    maxChannel = channelCount - 2;
    for chan1 = 1:(maxChannel)
      for chan2 = chan1+1:(maxChannel)
        maxPairs = maxPairs + 1;
        indexTable(maxPairs, 1) = maxPairs;
        indexTable(maxPairs, 2) = chan1;
        indexTable(maxPairs, 3) = chan2;
        pairLabels{maxPairs}= sprintf('%s-%s',labels{chan1},labels{chan2});
      end
    end
    
    channelPair.coherence = [];
    channelPair.label = '';
    pairCounter = 1;
    
    stat.meanCoherences = NaN(maxChannel,maxChannel,5);
    stat.stdDevCoherences = NaN(maxChannel,maxChannel,5);
    stat.skewCoherences = NaN(maxChannel,maxChannel,5);
    stat.kurtosisCoherences = NaN(maxChannel,maxChannel,5);
    if(doPhaseAngle)
      stat.meanPhaseAngle = NaN(maxChannel,maxChannel,5);
      stat.stdDevPhaseAngle = NaN(maxChannel,maxChannel,5);
      stat.skewPhaseAngle = NaN(maxChannel,maxChannel,5);
      stat.kurtosisPhaseAngle = NaN(maxChannel,maxChannel,5);
    end
    stat.channelLabels = labels(1:32);
    stat.filename = filename;
    
    for chan1 = 1:(maxChannel)
      channelPair.coherence = NaN(1,1);
      channelPair.phaseAngle = NaN(1,1);
      for chan2 = chan1+1:(maxChannel)
        %       fprintf('%d, %d\n',i,j);
        if(doPhaseAngle)
          [channelPair.coherence, channelPair.phaseAngle] = coherence(data(:,chan1), data(:,chan2));
          
        else
          [channelPair.coherence] = coherence(data(:,chan1), data(:,chan2));
        end
        stat.meanCoherences(chan1,chan2,:) = mean(channelPair.coherence);
        stat.stdDevCoherences(chan1,chan2,:) = std(channelPair.coherence);
        stat.skewCoherences(chan1,chan2,:) = skewness(channelPair.coherence);
        stat.kurtosisCoherences(chan1,chan2,:) = kurtosis(channelPair.coherence);
        if(doPhaseAngle)
          stat.meanPhaseAngle(chan1,chan2,:) = mean(channelPair.phaseAngle);
          stat.stdDevPhaseAngle(chan1,chan2,:) = std(channelPair.phaseAngle);
          stat.skewPhaseAngle(chan1,chan2,:) = skewness(channelPair.phaseAngle);
          stat.kurtosisPhaseAngle(chan1,chan2,:) = kurtosis(channelPair.phaseAngle);
        end
        stat.coherenceThreshold = .9;
        supraThreshold = channelPair.coherence > stat.coherenceThreshold ;
        for i = 1:size(supraThreshold,2)
          %         fprintf('.');
          %         if(mod(i, 100)==0)
          %           fprintf('\n%d', i);
          %         end
          a = supraThreshold(:,i);
          b = diff(a);
          rising = find(b == 1);
          falling = find(b == -1);
          while(isFallingLessThanRising(falling,rising))
            falling(1) = [];
          end
          while(length(rising) > length(falling))
            rising(end) = [];
          end
          while(length(rising) < length(falling))
            falling(end) = [];
          end
          %chop the end off because coherence has some lag in finding quality
          %data.
          falling = falling - 64;
          if((length(rising) > 0) && (length(falling) > 0))
            epochLengths = falling - rising;
          else
            epochLengths = [];
          end
          minEpochLength = 129;
          goodEpoch = find(epochLengths > minEpochLength);
          rising = rising .* 16 + 1024;
          falling = falling .* 16 + 1024;
          freqLabels = [{'Delta'}, {'Theta'}, {'Alpha'}, {'Beta'}, {'Hibeta'}];
          risingLabel = sprintf('supraThreshold%sEpochStart', freqLabels{i});
          fallingLabel = sprintf('supraThreshold%sEpochEnd', freqLabels{i});
          stat.(risingLabel) = rising(goodEpoch);
          stat.(fallingLabel) = falling(goodEpoch);
        end
        
        
        if(any(any(isnan(channelPair.coherence))));
          fprintf('i = %d, j = %d\n', chan1, chan2);
          error('unexpected coherenceValue');
        end
        channelPair.label =  sprintf('%s-%s',labels{chan1},labels{chan2});
        progress = sprintf('(%s) file %d/%d, channelPair %d/%d\n',char(datetime), fileCounter, length(filenames),pairCounter,maxPairs);
        fprintf(progress);
        save(outputPath, 'progress');
        channelPairs(pairCounter) = channelPair;
        pairCounter = pairCounter + 1;
        if(false)
          %debug
          normalizedPhaseAngle = channelPair.phaseAngle ./ (2*pi) + .5;
          figure;
          hold on;
          plot(channelPair.coherence(:,1), 'r');
          plot(normalizedPhaseAngle, 'b');
          legend('coherence', 'phase');
          pan xon;
          zoom xon;
          %end debug
        end
      end
    end
    
    if(summaryOnly)
      save(outputPath, 'stat', '-v7.3');
    else
      save(outputPath, 'channelPairs', 'filename', '-v7.3');
    end
  end
end



%
%
%     for pairCounter = 1:maxPairs
%       i = 1;
%       j = 2;
%       thisPair = 1;
%       while(thisPair ~= pairCounter)
%         j = j + 1;
%         if(j > length(labels))
%           i = i + 1;
%           j = i + 1;
%         end
%         thisPair = thisPair + 1;
%       end
%       fprintf('%d, %d\n',i,j);
%
% %       i = indexTable(pairCounter,2);
% %       j = indexTable(pairCounter,3);
%       channelPair(pairCounter).coherence = coherence(data(:,i), data(:,j));
%       channelPair(pairCounter).label = labels(pairCounter);
%       fprintf('%d/%d\n',pairCounter,maxPairs);
%       channelPairs(pairCounter) = channelPair;
%     end
%     save('/home/data/EEG/processed/Robi/coherence/ROBI_003_outcomeEOCoherence.mat', 'channelPairs');
%
