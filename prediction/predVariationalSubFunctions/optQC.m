tic;

% calculate components to directly calculate the omegaTerms
Sigma_c = (factorsPrecAVec + sigma_tilde_squared(idxB).^-1).^-1;
Sigma_c = eval(sprintf('%s(Sigma_c)',collector.options.dataTypeCast));

mu_c = Sigma_c(ones(1,numRows),:).*(sigma_tilde_squared(ones(1,numRows),idxB).^-1.*mu_a_b(idxB,ones(1,numRows))') + Sigma_c(ones(1,numRows),:).*(factorsPrecAVec(ones(1,numRows),:).*mu_a_b2'); 
mu_c = eval(sprintf('%s(mu_c)',collector.options.dataTypeCast));

c_c = (1./sqrt(2*pi*(factorsPrecAVec(ones(1,numRows),:).^-1) + sigma_tilde_squared(ones(1,numRows),idxB))'.*exp(-0.5*(mu_a_b2 - mu_a_b(idxB,ones(1,numRows))).^2.*(factorsPrecAVec(ones(1,numRows),:)'.^-1 + sigma_tilde_squared(ones(1,numRows),idxB)').^-1))';
c_c(c_c < options.thresholdAccuracy) = 0;
c_c = eval(sprintf('%s(c_c)',collector.options.dataTypeCast));

% call the c-function in case we need not to calculate pair
timeCFunc = 0;
a = tic; q_cc = optQCC(double(condQB),prediction,double(Sigma_c.^-1),double(mu_c),double(c_c),double(mu_a_b2'),numColumnsPred,numColumnsShape,columnsPredShapeVec(1,:),columnsPredShapeFactorVec(1,:),columnsPredShapeVec(2,:),columnsPredShapeFactorVec(2,:),double(factorsPrecAVec),hashTable); 
q_c.singleton = permute(reshape(q_cc,[numRows,numBounds,numColumnsPred,numVolRegions]),[4,3,2,1]);
timeCFunc = toc(a);
	
if collector.options.printTimings
	GPUsync;
	fprintf('[optQC]: %.3f s (C-Func %.3f)\n',toc,timeCFunc);
end

if options.plotting
   for volRegion = 1:numVolRegions
		idx = (1:numBounds*numColumnsShape(volRegion)) + sum(numColumnsShape(1:volRegion-1))*numBounds;
		toPlot = squeeze(sum(permute(squeeze(q_c.singleton(volRegion,:,:,:)),[2 3 1]).*repmat(1:numRows,[numBounds,1,numColumnsPred]),2));
		fileSaveName = sprintf('%s/qc_%d/%s_%d.eps',folderName,iter,filename,collector.options.labelIDs(volRegion));
		eval(sprintf('plotBScan(B%d,toPlot,collector.options.columnsPred,fileSaveName)',collector.options.labelIDs(volRegion)));
    end
end

% old matlab implementation; implicitly uses OmegaMatrices (see calcFuncVal for code to calculate these matrices)
%tic;
%for volRegion = 1:numVolRegions
%	mu_a_b = mu_a_b2((1:numColumnsShape(volRegion)*(numBounds-1)) + sum(numColumnsShape(1:volRegion-1))*(numBounds-1),:);
%
%	for j = 1:numColumnsPred
%		pObs = squeeze(prediction(:,:,j,volRegion))';
%
%		alpha = zeros(numBounds,numRows);
%		beta = zeros(numBounds,numRows);
%		c = size(1,numBounds);
%		numPrevCols = (0:numBounds-1)*numColumnsShape(volRegion) + sum(numColumnsShape(1:volRegion-1))*numBounds;
%		% idx not considering the first boundary
%		numPrevColsWithout = (0:numBounds-2)*numColumnsShape(volRegion) + sum(numColumnsShape(1:volRegion-1))*(numBounds-1);
%
%		% do the forward message passing
%		alpha(1,:) = (columnsPredShapeFactor{volRegion}(1,j)*condQB(:,columnsPredShape{volRegion}(1,j)+numPrevCols(1)) + (columnsPredShapeFactor{volRegion}(2,j)*condQB(:,columnsPredShape{volRegion}(2,j)+numPrevCols(1)))).*pObs(1,:)';
%		c(1) = sum(alpha(1,:));
%		alpha(1,:) = alpha(1,:)/c(1);
%		for i = 2:numBounds
%			idxNonZeroA = find((condQB(:,columnsPredShape{volRegion}(1,j)+numPrevCols(i)) + condQB(:,columnsPredShape{volRegion}(2,j)+numPrevCols(i)))~=0);
%			idxNonZeroB = find(alpha(i-1,:)~=0);
%
%			% directly calculates the marginals conditioned on all other boundaries
%			alpha(i,idxNonZeroA) = pObs(i,idxNonZeroA).*((alpha(i-1,idxNonZeroB)*columnsPredShapeFactor{volRegion}(1,j).*c_c(idxNonZeroB,columnsPredShape{volRegion}(1,j)+numPrevColsWithout(i-1))')*exp(-0.5*Sigma_c(columnsPredShape{volRegion}(1,j)+numPrevColsWithout(i-1))^-1*((idxNonZeroA(:,ones(1,length(idxNonZeroB)))' - mu_c(idxNonZeroB,ones(1,length(idxNonZeroA))*(columnsPredShape{volRegion}(1,j)+numPrevColsWithout(i-1)))).^2)) + ...
%			(alpha(i-1,idxNonZeroB)*columnsPredShapeFactor{volRegion}(2,j).*c_c(idxNonZeroB,columnsPredShape{volRegion}(2,j)+numPrevColsWithout(i-1))')*exp(-0.5*Sigma_c(columnsPredShape{volRegion}(2,j)+numPrevColsWithout(i-1))^-1*((idxNonZeroA(:,ones(1,length(idxNonZeroB)))' - mu_c(idxNonZeroB,ones(1,length(idxNonZeroA))*(columnsPredShape{volRegion}(2,j)+numPrevColsWithout(i-1)))).^2)));
%
%			% scale alpha
%			c(i) = sum(alpha(i,:));
%			alpha(i,:) = alpha(i,:)/c(i);
%		end
%
%		% do the backward message passing
%		beta(end,:) = ones(1,numRows);
%
%		for i = numBounds-1:-1:1
%			idxNonZeroA = (condQB(:,columnsPredShape{volRegion}(1,j)+numPrevCols(i+1)) + condQB(:,columnsPredShape{volRegion}(2,j)+numPrevCols(i+1)))~=0;
%			idxNonZeroB = beta(i+1,:)~=0;
%			idxFinal = find(logical(idxNonZeroA.*idxNonZeroB'));
%			idxB_ = find(alpha(i,:)~=0);
%
%			beta(i,idxB_) = columnsPredShapeFactor{volRegion}(1,j)/c(i+1)*(beta(i+1,idxFinal).*pObs(i+1,idxFinal).*condQB(idxFinal,(columnsPredShape{volRegion}(1,j)+numPrevCols(i+1)))')*exp(-0.5*factorsPrecA{volRegion}((i-1)*numColumnsShape(volRegion)+columnsPredShape{volRegion}(1,j))*(idxFinal(:,ones(1,length(idxB_)))' - mu_a_b(ones(1,length(idxFinal))*((i-1)*numColumnsShape(volRegion)+columnsPredShape{volRegion}(1,j)),idxB_)').^2)' ...
%			+ columnsPredShapeFactor{volRegion}(2,j)/c(i+1)*(beta(i+1,idxFinal).*pObs(i+1,idxFinal).*condQB(idxFinal,(columnsPredShape{volRegion}(2,j)+numPrevCols(i+1)))')*exp(-0.5*factorsPrecA{volRegion}((i-1)*numColumnsShape(volRegion)+columnsPredShape{volRegion}(2,j))*(idxFinal(:,ones(1,length(idxB_)))' - mu_a_b(ones(1,length(idxFinal))*((i-1)*numColumnsShape(volRegion)+columnsPredShape{volRegion}(2,j)),idxB_)').^2)';
%		end
%		
%		tmp = sum(alpha.*beta,2);
%		q_c.singleton(volRegion,j,:,:) = alpha.*beta./tmp(:,ones(1,numRows));
%		% calc pairwise terms in order to calculate the value of the energy function
%		if options.calcFuncVal
%			for i = 2:numBounds
%				q_c.pairwise{volRegion,j,i-1} = sparse(c(i)^-1.*alpha((i-1)*ones(1,numRows),:)'.*pObs(i*ones(numRows,1),:).*omegaTerms{volRegion,i,j}.*beta(i*ones(1,numRows),:));
%				q_c.pairwise{volRegion,j,i-1} = q_c.pairwise{volRegion,j,i-1}/sum(sum(q_c.pairwise{volRegion,j,i-1}));
%			end
%		end
%		end
%	end
%	toc;
%end

