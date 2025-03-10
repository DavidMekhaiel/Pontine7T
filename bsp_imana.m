function varargout=bsp_imana(what,varargin)
% Script for minimal preprocessing of the Pontine7T data
% 
numDummys = 3;                                                              % per run
numTRs    = 328;                                                            % per run (includes dummies)
%========================================================================================================================
% PATH DEFINITIONS
baseDir         ='/srv/diedrichsen/data/Cerebellum/Pontine7T';
if ~exist(baseDir,'dir')
    baseDir         ='/Volumes/diedrichsen_data$/data/Cerebellum/Pontine7T';
end
imagingDir      ='/imaging_data';
imagingDirRaw   ='/imaging_data_raw';
anatomicalDir   ='/anatomicals';
suitDir         ='/suit';
regDir          ='/RegionOfInterest';
%========================================================================================================================
% PRE-PROCESSING 
subj_pilot = {'S99'};
loc_AC_pilot = {[79;127;127]};
subj_name = {'S98','S97','S96','S95','S01'};
loc_AC={[80;129;120];[77;125;129];[90;129;138];[78;131;127];[77;125;122]}; % 
%========================================================================================================================
% GLM INFO
funcRunNum  = [50,65];  % first and last behavioural run numbers
%run         = {'01','02','03','04','05','06','07','08','09','10','11','12'};
run         = {'01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16'};
%run         = {'09','10','11','12','13','14','15','16','01','02','03','04','05','06','07','08'};
runB        = [50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65];  % Behavioural labelling of runs
%========================================================================================================================
switch(what)

    case 'ANAT:reslice_LPI'           % Reslice anatomical image within LPI coordinate systems  
        % example: bsp_imana('ANAT:reslice_LPI',1)
        sn  = varargin{1}; % subjNum 
        subjs=length(sn);
        
        for s=1:subjs,
            
            % (1) Reslice anatomical image to set it within LPI co-ordinate frames
            source  = fullfile(baseDir,anatomicalDir,subj_name{sn(s)},'anatomical_raw.nii');
            dest    = fullfile(baseDir,anatomicalDir,subj_name{sn(s)},'anatomical.nii');
            spmj_reslice_LPI(source,'name', dest);
            
            % (2) In the resliced image, set translation to zero
            V               = spm_vol(dest);
            dat             = spm_read_vols(V);
            V.mat(1:3,4)    = [0 0 0];
            spm_write_vol(V,dat);
            display 'Manually retrieve the location of the anterior commissure (x,y,z) before continuing'
        end
    case 'ANAT:center_AC'             % Re-centre AC
        % Before running provide coordinates in the preprocessing section
        % example: bsp_imana('ANAT:centre_AC',1)
        sn=varargin{1}; % subjNum
        
        subjs=length(sn);
        for s=1:subjs,
            img    = fullfile(baseDir,anatomicalDir,subj_name{sn(s)},'anatomical.nii');
            V               = spm_vol(img);
            dat             = spm_read_vols(V);
            oldOrig         = V.mat(1:3,4);
            V.mat(1:3,4)    = oldOrig-loc_AC{sn(s)};
            spm_write_vol(V,dat);
            fprintf('Done for %s \n',subj_name{sn(s)})
        end
    case 'ANAT:segmentation'          % Segmentation + Normalisation
        % example: bsp_imana('ANAT:segmentation',1)
        sn=varargin{1}; % subjNum
        
        subjs=length(sn);
        
        SPMhome=fileparts(which('spm.m'));
        J=[];
        for s=1:subjs,
            J.channel.vols = {fullfile(baseDir,anatomicalDir,subj_name{sn(s)},'anatomical.nii,1')};
            J.channel.biasreg = 0.001;
            J.channel.biasfwhm = 60;
            J.channel.write = [0 0];
            J.tissue(1).tpm = {fullfile(SPMhome,'tpm/TPM.nii,1')};
            J.tissue(1).ngaus = 1;
            J.tissue(1).native = [1 0];
            J.tissue(1).warped = [0 0];
            J.tissue(2).tpm = {fullfile(SPMhome,'tpm/TPM.nii,2')};
            J.tissue(2).ngaus = 1;
            J.tissue(2).native = [1 0];
            J.tissue(2).warped = [0 0];
            J.tissue(3).tpm = {fullfile(SPMhome,'tpm/TPM.nii,3')};
            J.tissue(3).ngaus = 2;
            J.tissue(3).native = [1 0];
            J.tissue(3).warped = [0 0];
            J.tissue(4).tpm = {fullfile(SPMhome,'tpm/TPM.nii,4')};
            J.tissue(4).ngaus = 3;
            J.tissue(4).native = [1 0];
            J.tissue(4).warped = [0 0];
            J.tissue(5).tpm = {fullfile(SPMhome,'tpm/TPM.nii,5')};
            J.tissue(5).ngaus = 4;
            J.tissue(5).native = [1 0];
            J.tissue(5).warped = [0 0];
            J.tissue(6).tpm = {fullfile(SPMhome,'tpm/TPM.nii,6')};
            J.tissue(6).ngaus = 2;
            J.tissue(6).native = [0 0];
            J.tissue(6).warped = [0 0];
            J.warp.mrf = 1;
            J.warp.cleanup = 1;
            J.warp.reg = [0 0.001 0.5 0.05 0.2];
            J.warp.affreg = 'mni';
            J.warp.fwhm = 0;
            J.warp.samp = 3;
            J.warp.write = [1 1];
            matlabbatch{1}.spm.spatial.preproc=J;
            spm_jobman('run',matlabbatch);
            fprintf('Check segmentation results for %s\n', subj_name{sn(s)})
        end;
        
    case 'ANAT:coregTSE'                 % Adjust TSE to anatomical image REQUIRES USER INPUT
        % (2) Manually seed the functional/anatomical registration
        % - Do "coregtool" on the matlab command window
        % - Select anatomical image and tse image to overlay
        % - Manually adjust tse image and save result as rtse image
        % example: bsp_imana('ANAT:coregTSE',1,'auto')
        sn=varargin{1};% subjNum
        step=varargin{2}; % first 'manual' then 'auto'
        
        cd(fullfile(baseDir,anatomicalDir,subj_name{sn}));
        
        switch step,
            case 'manual'
                coregtool;
                keyboard();
            case 'auto'
                % do nothing
        end
        
        % (1) Automatically co-register functional and anatomical images for study 1
        J.ref = {fullfile(baseDir,anatomicalDir,subj_name{sn},'anatomical.nii')};
        J.source = {fullfile(baseDir,anatomicalDir,subj_name{sn},'tse.nii')};
        J.other = {''};
        J.eoptions.cost_fun = 'nmi';
        J.eoptions.sep = [4 2];
        J.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        J.eoptions.fwhm = [7 7];
        matlabbatch{1}.spm.spatial.coreg.estimate=J;
        spm_jobman('run',matlabbatch);
        
        % NOTE:
        % Overwrites tse, unless you update in step one, which saves it
        % as rtse.
        % Each time you click "update" in coregtool, it saves current
        % alignment by appending the prefix 'r' to the current file
        % So if you continually update rtse, you'll end up with a file
        % called r...rrrtsei.
        
    case 'FUNC:remDum'                % Remove the extra dummy scans from all functional runs.
        % funtional runs have to be named as run_01-r.nii, run_02-r.nii ...
        % example: bsp_imana('FUNC:remDum',1)
        sn=varargin{1}; % subjNum
        
        subjs=length(sn);
        for s=1:subjs,
            cd(fullfile(baseDir,imagingDirRaw,[subj_name{sn(s)},'-n']));
            funScans = dir('*-r.nii');
            for i=1:length(funScans)  
                outfilename = sprintf('run_%2.2d.nii',i);
                mkdir temp;
                spm_file_split(funScans(i).name,'temp');
                cd temp;
                list = dir('run*.nii');
                list = list(numDummys+1:end);  % Remove dummies
                V = {list(:).name};
                spm_file_merge(V,outfilename);
                movefile(outfilename,fullfile(baseDir,imagingDirRaw,[subj_name{sn(s)} '-n']))
                cd ..
                rmdir('temp','s');
                fprintf('Run %d done for %s \n',i,subj_name{sn(s)});
            end;
        end
    case 'FUNC:realign'               % Realign functional images (both sessions)
        % SPM realigns all volumes to the first volume of first run
        % example: bsp_imana('FUNC:realign',1,[1:4])
        
        sn=varargin{1}; %subjNum
        runs=varargin{2}; % runNum
        
        subjs=length(sn);
        
        for s=1:subjs,
            
            cd(fullfile(baseDir,imagingDirRaw,[subj_name{sn(s)} '-n']));
            spm_jobman % run this step first
            
            data={};
            for i = 1:length(runs),
                for j=1:numTRs-numDummys;
                    data{i}{j,1}=sprintf('run_%2.2d.nii,%d',runs(i),j);
                end;
            end;
            spmj_realign(data);
            fprintf('runs realigned for %s\n',subj_name{sn(s)});
        end
    case 'FUNC:correct deform'        % Correct Magnetic field deformations using antsRegEpi.sh
    case 'FUNC:move_data'             % Move realigned data
        % Moves image data from imaging_data_raw into imaging_data.
        % example: bsp_imana('FUNC:move_data',1,[1:4])
        sn=varargin{1}; % subjNum
        runs=varargin{2}; % runNum
        
        subjs=length(sn);
        
        for s=1:subjs,
            dircheck(fullfile(baseDir,imagingDir,subj_name{sn(s)}))
            for r=1:length(runs);
                % move realigned data for each run
                source = fullfile(baseDir,imagingDirRaw,[subj_name{sn(s)} '-n'],sprintf('rrun_%2.2d.nii',runs(r)));
                dest = fullfile(baseDir,imagingDir,subj_name{sn(s)},sprintf('run_%2.2d.nii',runs(r)));
                copyfile(source,dest);
                
                % move realignment parameter files for each run
                source = fullfile(baseDir,imagingDirRaw,[subj_name{sn(s)} '-n'],sprintf('rp_run_%2.2d.txt',runs(r)));
                dest = fullfile(baseDir,imagingDir,subj_name{sn(s)},sprintf('rp_run_%2.2d.txt',runs(r)));
                copyfile(source,dest);
            end;            
            
            fprintf('realigned epi''s moved for %s \n',subj_name{sn(s)})
        end
   
    case 'FUNC:coregEPI'      % Adjust meanepi to anatomical image REQUIRES USER INPUT
        % (2) Manually seed the functional/anatomical registration
        % - Do "coregtool" on the matlab command window
        % - Select anatomical image and meanepi image to overlay
        % - Manually adjust meanepi image and save result as rmeanepi image
        % example: bsp_imana('FUNC:coregEPI',1)
        sn=varargin{1};% subjNum
        
        % (1) Automatically co-register functional and anatomical images for study 1
        J.ref = {fullfile(baseDir,anatomicalDir,subj_name{sn},'rtse.nii')};
        J.source = {fullfile(baseDir,imagingDirRaw,[subj_name{sn} '-n'],'rmeanrun_01.nii')};
        J.other = {''};
        J.eoptions.cost_fun = 'ncc';
        J.eoptions.sep = [4 2];
        J.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        J.eoptions.fwhm = [7 7];
        matlabbatch{1}.spm.spatial.coreg.estimate=J;
        spm_jobman('run',matlabbatch);
        
    case 'FUNC:make_samealign'        % Align functional images to rmeanepi of study 1
        % Aligns all functional images from both sessions (each study done separately)
        % to rmeanepi of study 1
        % example: bsp_imana('FUNC:make_samealign',1,[1:32])
        sn=varargin{1}; % subjNum
        runs=varargin{2}; % runNum
        
        subjs=length(sn);
        
        for s=1:subjs,
            
            cd(fullfile(baseDir,imagingDir,subj_name{sn(s)}));
            
            % Select image for reference
            % For ants-registered data: TSE 
            % P{1} = fullfile(fullfile(baseDir,anatomicalDir,subj_name{sn},'tse.nii'));
            % for tradition way: rmeanepi 
            P{1} = fullfile(fullfile(baseDir,imagingDir,subj_name{sn},'rmeanrun_01.nii'));
            
            % Select images to be realigned
            Q={};
            for r=1:numel(runs)
              Q{end+1}    = fullfile(baseDir,imagingDir,subj_name{sn(s)},sprintf('run_%2.2d.nii',runs(r)));
            end;
            
            % Run spmj_makesamealign_nifti
            spmj_makesamealign_nifti(char(P),char(Q));
            fprintf('functional images realigned for %s \n',subj_name{sn(s)})
        end
        
        %spmj_checksamealign
    
    case 'SUIT:isolate'               % Segment cerebellum into grey and white matter
        % LAUNCH SPM FMRI BEFORE RUNNING!!!!!
        sn=varargin{1};
        %         spm fmri
        for s=sn,
            suitSubjDir = fullfile(baseDir,suitDir,'anatomicals',subj_name{s});dircheck(suitSubjDir);
            source=fullfile(baseDir,anatomicalDir,subj_name{s},'anatomical.nii');
            dest=fullfile(suitSubjDir,'anatomical.nii');
            copyfile(source,dest);
            cd(fullfile(suitSubjDir));
            suit_isolate_seg({fullfile(suitSubjDir,'anatomical.nii')},'keeptempfiles',1);
        end
        
    case 'SUIT:normalise_dartel'     % Uses an ROI from the dentate nucleus to improve the overlap of the DCN
        % Create the dentate mask in the imaging folder using the tse
        % LAUNCH SPM FMRI BEFORE RUNNING!!!!!
        sn=varargin{1}; %subjNum
        % example: 'sc1_sc2_imana('SUIT:normalise_dentate',1)
        
        cd(fullfile(baseDir,suitDir,'anatomicals',subj_name{sn}));
        job.subjND.gray       = {'c_anatomical_seg1.nii'};
        job.subjND.white      = {'c_anatomical_seg2.nii'};
        job.subjND.isolation  = {'c_anatomical_pcereb_corr.nii'};
        suit_normalize_dartel(job);
        
    case 'SUIT:normalise_dentate'     % Uses an ROI from the dentate nucleus to improve the overlap of the DCN
        % Create the dentate mask in the imaging folder using the tse 
        sn=varargin{1}; %subjNum
        % example: 'sc1_sc2_imana('SUIT:normalise_dentate',1)
        
        cd(fullfile(baseDir,suitDir,'anatomicals',subj_name{sn}));
        job.subjND.gray       = {'c_anatomical_seg1.nii'};
        job.subjND.white      = {'c_anatomical_seg2.nii'};
        job.subjND.dentateROI = {'dentate_mask.nii'};
        job.subjND.isolation  = {'c_anatomical_pcereb_corr.nii'};
        suit_normalize_dentate(job);
    
    case 'SUIT:reslice_ana'               % Reslice the contrast images from first-level GLM
        % example: bsm_imana('SUIT:reslice',1,'anatomical')
        % make sure that you reslice into 2mm^3 resolution
        sn=varargin{1}; % subjNum
        image=varargin{2}; % 'betas' or 'contrast' or 'ResMS' or 'cerebellarGrey'
        
        for s=sn
            suitSubjDir = fullfile(baseDir,suitDir,'anatomicals',subj_name{s});             
            job.subj.affineTr = {fullfile(suitSubjDir ,'Affine_c_anatomical_seg1.mat')};
            job.subj.flowfield= {fullfile(suitSubjDir ,'u_a_c_anatomical_seg1.nii')};
            job.subj.mask     = {fullfile(suitSubjDir ,'c_anatomical_pcereb_corr.nii')};
            switch image
                case 'anatomical'
                    sourceDir = suitSubjDir; 
                    source = fullfile(sourceDir,'anatomical.nii'); 
                    job.subj.resample = {source};
                    outDir = suitSubjDir; 
                    job.vox           = [1 1 1];
                case 'TSE'
                    sourceDir = fullfile(baseDir,'anatomicals',subj_name{s}); 
                    source = fullfile(sourceDir,'rtse.nii');
                    job.subj.resample = {source};
                    outDir = suitSubjDir; 
                    job.vox           = [1 1 1];
                case 'csf'
                    sourceDir = fullfile(baseDir,'anatomicals',subj_name{s}); 
                    source = fullfile(sourceDir,'c3anatomical.nii');
                    job.subj.resample = {source};
                    job.subj.mask     =  {}; 
                    outDir = suitSubjDir; 
                    job.vox           = [1 1 1];
            end
            suit_reslice_dartel(job);   
            source=fullfile(sourceDir,'*wd*');
            movefile(source,outDir);
        end
        
    case 'SUIT:reslice'               % Reslice the contrast images from first-level GLM
        % example: bsm_imana('SUIT:reslice',1,4,'betas','cereb_prob_corr_grey')
        % make sure that you reslice into 2mm^3 resolution
        sn=2; % subjNum
        glm=1; % glmNum
        type='contrast'; % 'betas' or 'contrast' or 'ResMS' or 'cerebellarGrey'
        mask='c_anatomical_pcereb_corr'; % 'cereb_prob_corr_grey' or 'cereb_prob_corr' or 'dentate_mask'
        
        v
        subjs=length(sn);
        
        for s=1:subjs,
            switch type
                case 'betas'
                    glmSubjDir = fullfile(baseDir,sprintf('GLM_firstlevel_%d',glm),subj_name{sn(s)});
                    outDir=fullfile(baseDir,suitDir,sprintf('glm%d',glm),subj_name{sn(s)});
                    images='beta_0';
                    source=dir(fullfile(glmSubjDir,sprintf('*%s*',images))); % images to be resliced
                    cd(glmSubjDir);
                case 'contrast'
                    glmSubjDir = fullfile(baseDir,sprintf('GLM_firstlevel_%d',glm),subj_name{sn(s)});
                    outDir=fullfile(baseDir,suitDir,sprintf('glm%d',glm),subj_name{sn(s)});
                    images='con';
                    source=dir(fullfile(glmSubjDir,sprintf('*%s*',images))); % images to be resliced
                    cd(glmSubjDir);
                case 'ResMS'
                    glmSubjDir = fullfile(baseDir,sprintf('GLM_firstlevel_%d',glm),subj_name{sn(s)});
                    outDir=fullfile(baseDir,suitDir,sprintf('glm%d',glm),subj_name{sn(s)});
                    images='ResMS';
                    source=dir(fullfile(glmSubjDir,sprintf('*%s*',images))); % images to be resliced
                    cd(glmSubjDir);
                case 'cerebellarGrey'
                    source=dir(fullfile(baseDir,suitDir,'anatomicals',subj_name{sn(s)},'c1anatomical.nii')); % image to be resliced
                    cd(fullfile(baseDir,suitDir,'anatomicals',subj_name{sn(s)}));
            end
            job.subj.affineTr = {fullfile(baseDir,suitDir,'anatomicals',subj_name{sn(s)},'Affine_c_anatomical_seg1.mat')};
            job.subj.flowfield= {fullfile(baseDir,suitDir,'anatomicals',subj_name{sn(s)},'u_a_c_anatomical_seg1.nii')};
            job.subj.resample = {source.name};
            job.subj.mask     = {fullfile(baseDir,suitDir,'anatomicals',subj_name{sn(s)},sprintf('%s.nii',mask))};
            job.vox           = [1 1 1];
            % Replace Nans with zeros to avoid big holes in the the data 
            for i=1:length(source)
                V=spm_vol(source(i).name); 
                X=spm_read_vols(V); 
                X(isnan(X))=0; 
                spm_write_vol(V,X); 
            end; 
            suit_reslice_dartel(job);
            
            source=fullfile(glmSubjDir,'*wd*');
            dircheck(fullfile(outDir));
            destination=fullfile(baseDir,suitDir,sprintf('glm%d',glm),subj_name{sn(s)});
            movefile(source,destination);

            fprintf('%s have been resliced into suit space \n',type)
        end
    case 'SUIT:map_to_flat' 
        sn = 2; 
        glm = 1; 
        vararginoptions(varargin,{'sn','glm','type','mask'});
        source_dir=fullfile(baseDir,suitDir,sprintf('glm%d',glm),subj_name{sn});
        source=dir(fullfile(source_dir,'wdcon*')); % images to be resliced
        for i=1:length(source)
            name{i} = fullfile(source_dir,source(i).name); 
        end; 
        MAP = suit_map2surf(name); 
        % G = surf_makeFuncGifti
        set(gcf,'PaperPosition',[2 2 15 7]);
        wysiwyg; 
        for i=1:10 
            subplot(2,5,i); 
            suit_plotflatmap(MAP(:,i),'cscale',[-1.5 1.5]); 
            n = source(i).name(7:end-4); 
            n(n=='_')=' '; 
            title(n); 
        end; 
        
        
    case 'PHYS:extract'               % Extract puls and resp files from dcm
        sn=varargin{1};
        
        cd (fullfile(baseDir,'physio',subj_name{sn}));
        logfiles = dir('*.dcm');
        
        for lFile = 1:length(logfiles)
            fname = strsplit(logfiles(lFile).name,'.');
            mkdir(fname{1});
            movefile(logfiles(lFile).name,fname{1})
            cd (fname{1})
            extractCMRRPhysio(logfiles(lFile).name);
            cd ..
        end
    case 'PHYS:createRegressor'       % Create Retroicor regressors using TAPAS (18 components)
        sn=4; 
        run = [1:16]; 
        stop = true; 
        vararginoptions(varargin,{'sn','run','stop'}); 
        
        for nrun= run
            
            logDir = fullfile(baseDir,'physio',subj_name{sn},sprintf('run%2.2d',nrun));
            cd (logDir);
            PULS = dir('*PULS.log');
            RSP  = dir('*RESP.log');
            log  = dir('*Info.log');
            
            % 2. Define physio model structure
            physio = tapas_physio_new();
            
            % 3. Define input files
            physio.save_dir = {logDir};                         % enter directory to save physIO output
            physio.log_files.cardiac = {PULS.name};             % .puls file
            physio.log_files.respiration = {RSP.name};          % .resp file
            physio.log_files.scan_timing = {log.name};          % Log file
            physio.log_files.vendor = 'Siemens_Tics';           % Vendor
            physio.log_files.relative_start_acquisition = 0;    % only used for Philips
            physio.log_files.align_scan = 'last';               % sync log and EPI files from the last scan
            
            % 4. Define scan timing parameters
            physio.scan_timing.sqpar.Nslices = 60;              % number of slices in EPI volume
            physio.scan_timing.sqpar.TR = 1;                    % TR in secs
            physio.scan_timing.sqpar.Ndummies = numDummys;      % Real dummy are not recorded
            physio.scan_timing.sqpar.Nscans = numTRs-numDummys; % number of time points/scans/volumes
            physio.scan_timing.sqpar.onset_slice = 30;          % slice of interest (choose middle slice if unsure?)
            physio.scan_timing.sync.method = 'scan_timing_log'; % using info file
            
            % 5. Define cardiac data parameters
            physio.preproc.cardiac.modality = 'PPU';        % cardiac data acquired with PPU
            physio.preproc.cardiac.initial_cpulse_select.max_heart_rate_bpm = 110; % Allow higher heart rate to start
            physio.preproc.cardiac.initial_cpulse_select.auto_matched.min = 0.4;
            physio.preproc.cardiac.initial_cpulse_select.auto_matched.file = 'initial_cpulse_kRpeakfile.mat';
            physio.preproc.cardiac.posthoc_cpulse_select.off = struct([]);
            
            % 6. Define generic physio model parameters
            physio.model.orthogonalise = 'none';
            physio.model.output_multiple_regressors = 'multiple_regressors.txt';  %% regressor output filename
            physio.model.output_physio = 'physio.mat';  %% model output filename
            physio.model.censor_unreliable_recording_intervals = false;  %% set to true to automatically censor missing recording intervals
            
            % 7. RETROICOR phase expansion (Glover et al., 2000)
            physio.model.retroicor.include = true;  %% use RETROICOR to calculate regressors
            physio.model.retroicor.order.c = 3;
            physio.model.retroicor.order.r = 3;
            physio.model.retroicor.order.cr = 0;
            
            % 8. RVT respiratory volume per time (Birn et al., 2008)
            physio.model.rvt.include = true;
            physio.model.rvt.delays = 0;
            
            % 9. HRV heart rate response (Chang et al., 2009)
            physio.model.hrv.include = true;
            physio.model.hrv.delays = 0;
            
            % 10. ROI anatomical component-based noise extraction (aCompCor; Behzadi et al., 2007)
            physio.model.noise_rois.include = false;
            physio.model.noise_rois.thresholds = 0.9;
            physio.model.noise_rois.n_voxel_crop = 0;
            physio.model.noise_rois.n_components = 1;
            
            % 11. Motion modeling (Friston et al., 1996)
            physio.model.movement.include = false;
            physio.model.movement.file_realignment_parameters = {''};  %% No input required unless physio.model.movement.include is set to 'true'
            physio.model.movement.order = 6;
            physio.model.movement.outlier_translation_mm = 3;
            physio.model.movement.outlier_rotation_deg = Inf;
            
            % 12. Include other regressors
            physio.model.other.include = false;  %% include realignment parameters
            physio.model.other.input_multiple_regressors = {''};  %% rp*.txt file if needed
            
            % 13. Output/model options
            physio.verbose.level = 1;  %% 0 = suppress graphical output; 1 = main plots; 2 = debugging plots; 3 = all plots
            physio.verbose.process_log = cell(0, 1);
            physio.verbose.fig_handles = zeros(0, 1);
            physio.verbose.fig_output_file = [];  %% output figure filename (output format can be any matlab supported graphics format)
            physio.verbose.use_tabs = false;
            
            physio.ons_secs.c_scaling = 1;
            physio.ons_secs.r_scaling = 1;
            
            % 14. Run main script
            [physio_out,R,ons_sec]=tapas_physio_main_create_regressors(physio);
            % Save as different text files.... 
            dlmwrite('reg_retro_hr.txt',R(:,1:6));
            dlmwrite('reg_retro_resp.txt',R(:,7:12));
            dlmwrite('reg_hr.txt',[R(:,13) ons_sec.hr]); % Add the un-convolved version as well 
            dlmwrite('reg_rvt.txt',[R(:,14) ons_sec.rvt]); % add the un-convolved version as well 
            if (stop) 
                keyboard; 
                close all;
            end;
        end
    case 'ROI:inv_reslice'              % Defines ROIs for brain structures
        sn=varargin{1}; 
        images = {'csf','pontine','olive','dentate','rednucleus'}; 
        groupDir = fullfile(baseDir,'RegionOfInterest','group');
        
        for s=sn 
            regSubjDir = fullfile(baseDir,'RegionOfInterest','data',subj_name{s});
            glm_mask = fullfile(baseDir,'GLM_firstlevel_1',subj_name{s},'mask.nii');
            suitSubjDir = fullfile(baseDir,suitDir,'anatomicals',subj_name{s});             
            for im=1:length(images)
                job.Affine = {fullfile(suitSubjDir ,'Affine_c_anatomical_seg1.mat')};
                job.flowfield= {fullfile(suitSubjDir ,'u_a_c_anatomical_seg1.nii')};
                job.resample = {fullfile(groupDir,sprintf('%s_mask.nii',images{im}))}; 
                job.ref     = {glm_mask};
                suit_reslice_dartel_inv(job);
                source=fullfile(suitSubjDir,sprintf('iw_%s_mask_u_a_c_anatomical_seg1.nii',images{im}));
                dest  = fullfile(regSubjDir,sprintf('%s_mask.nii',images{im}));
                movefile(source,dest);

            end
        end
    case 'ROI:cerebellar_gray' 
        sn=varargin{1};
        for s = sn 
            suitSubjDir = fullfile(baseDir,suitDir,'anatomicals',subj_name{s});             
            regSubjDir = fullfile(baseDir,'RegionOfInterest','data',subj_name{s});
            P = {fullfile(baseDir,'GLM_firstlevel_1',subj_name{sn},'mask.nii'),...
                fullfile(suitSubjDir,'c_anatomical_seg1.nii'),...
                fullfile(suitSubjDir,'c_anatomical_pcereb_corr.nii')}; 
            outname = fullfile(regSubjDir,'cerebellum_gray_mask.nii'); 
            spm_imcalc(char(P),outname,'i1 & (i2>0.1) & (i3>0.3)',{0,0,1,4}); 
        end
    case 'ROI:define'                 % Defines ROIs for brain structures
        % Before runing this, create masks for different structures
        sn=2; 
        regions={'cerebellum_gray','csf','dentate','pontine','olive','rednucleus'};
        
        vararginoptions(varargin,{'sn','regions'}); 
        for s=sn
            regSubjDir = fullfile(baseDir,'RegionOfInterest','data',subj_name{s});
            for r = 1:length(regions)
                file = fullfile(regSubjDir,sprintf('%s_mask.nii',regions{r}));
                R{r}.type = 'roi_image';
                R{r}.file= file;
                R{r}.name = regions{r};
                R{r}.value = 1;
            end
            R=region_calcregions(R);                
            save(fullfile(regSubjDir,'regions.mat'),'R');
        end

           
end
        
 
  
