%% initialize working space and prepare for the computation
clear; clc; close all;
addpath('../functions/');
addpath('./extra');
work_dir = fileparts(mfilename('fullpath'));
prepare_env;
output_folder = [fig_folder, filesep, 'Fig_PFC_subfigs'];

results_folder = sprintf('%sfig_PFC%s', results_folder, filesep); 
if ~exist(results_folder, 'dir')
    mkdir(results_folder); 
end  
results_file = [results_folder, 'fig_PFC_results.mat'];
cellsort_folder = [code_folder, 'CellSort'];
addpath(cellsort_folder);
demixed_video = [video_folder, filesep, 'PFC_decompose.avi'];
overlap_video = [video_folder, filesep, 'PFC_overlapping.avi'];

if ~exist(results_file, 'file')
    save(results_file, 'hash_cnmfe', '-v7.3');
end
results_data = matfile(results_file, 'Writable', true);

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end
export_fig = true;
pixel_size = 1000/647; 

%% run CNMF-E or load results
nam = get_fullname('../../../data/PFC4_15Hz.mat');          % this demo data is very small, here we just use it as an example
try
    cnmfe_path = results_data.cnmfe_path;
catch
    cnmfe_path = [];
end
if exist(cnmfe_path, 'file')
    load(cnmfe_path);
else
    run_cnmfe;
    results_data.cnmfe_path = cnmfe_path;
end
frame_range = neuron.frame_range; 
if ~exist('Y', 'var')
    Y = neuron.load_patch_data([], frame_range);
end

% load raw data and reconstruct background  
Y = neuron.reshape(Y, 1);
Ybg = neuron.reconstruct_background();
Ybg = neuron.reshape(Ybg, 1);
Ysignal = neuron.reshape(double(Y), 1) - neuron.reshape(Ybg, 1); 

%% run PCA/ICA analysis or load results
nPCs = 275;
nICs = 250;
try
    neuron_ica = results_data.neuron_ica;
    A_ica_before_trim = results_data.A_ica_before_trim;
catch
    run_ica;
    results_data.A_ica_before_trim = A_ica_before_trim;
    results_data.A_ica = A_ica;
    results_data.C_ica = C_ica;
    
    neuron_ica.compress_results();
    results_data.neuron_ica = neuron_ica;
end

%% compute SNRs 
K_cnmfe = size(neuron.C_raw, 1); 
K_ica = size(neuron_ica.C, 1); 

snr_ica = var(neuron_ica.C, 0, 2)./var(neuron_ica.C_raw-neuron_ica.C, 0, 2); 
snr_cnmfe = var(neuron.C, 0, 2)./var(neuron.C_raw-neuron.C, 0, 2); 

[~, srt] = sort(snr_cnmfe, 'descend'); 
neuron.orderROIs(srt); 
snr_cnmfe = snr_cnmfe(srt); 

[~, srt] = sort(snr_ica, 'descend'); 
neuron_ica.orderROIs(srt); 
A_ica_before_trim = A_ica_before_trim(:, srt); 
snr_ica = snr_ica(srt); 

% remove ICA neurons whose SNRs are too small 
neuron_ica_bk = neuron_ica.copy(); 
A_ica_before_trim_bk = A_ica_before_trim; 
ind_del = find(snr_ica<min(snr_cnmfe)); 
neuron_ica.delete(ind_del); 
A_ica_before_trim(:, ind_del) = []; 

%% match neurons 
match_cnmfe = pair_neurons(neuron.A, neuron.C_raw, neuron_ica.A, neuron_ica.C_raw); 

ids_match = find(~isnan(match_cnmfe.ind_max)); 
ids_match(match_cnmfe.max_spatial(ids_match)<0.5) = []; 
ids_ica = match_cnmfe.ind_max(ids_match); 
K_match = length(ids_match); 

ind = 1:size(neuron.A,2); 
ind(ids_match) = []; 
srt = [ids_match, ind]; 
neuron.orderROIs(srt); 
snr_cnmfe = snr_cnmfe(srt); 

ind = 1:size(neuron_ica.A, 2); 
ind(ids_ica) = []; 
srt = [ids_ica, ind]; 
neuron_ica.orderROIs(srt); 
snr_ica = snr_ica(srt); 
A_ica_before_trim = A_ica_before_trim(:, srt);

%% show one frame and one neuron 
Ymin = 400; 
Ymax = 2200; 
Yacmin = 10; 
Yacmax = 250; 
d1 = neuron.options.d1; 
d2 = neuron.options.d2; 

[~, example_neuron] = max(neuron.A(sub2ind([d1,d2], 107,122), :));
ind_frame = 1301; 
% [~, ind_frame] = max(neuron.C(example_findneuron, :)); 
figure; 
% Cn_res = correlation_image(Ysignal-neuron.A*neuron.C, 8, d1, d2); 
coor = plot_contours(neuron.A(:,example_neuron), randn(d1,d2), 0.9, 0); 
close; 
% create a mask  for selecting ROI 
x = round(coor{1}(1,5:end)); 
y = round(coor{1}(2,5:end)); 
mask = false(d1,d2); 
for ii =1:length(x) 
    for jj=1:length(x)
        tmp_x = 0: (x(jj)-x(ii)); 
        if length(tmp_x)<2
            continue; 
        end
        tmp_y = y(ii)+(y(jj)-y(ii))/(x(jj)-x(ii))*tmp_x;
        mask(sub2ind([d1,d2], round(tmp_y), tmp_x+x(ii))) = true; 
    end 
end 

%% show decomposed images for one example frame
figure('papersize', [d2+50, d1]/max(d1,d2)*5);
init_fig;
Y = neuron.reshape(Y, 1); 
Ybg = neuron.reshape(Ybg, 1); 
Ysignal = neuron.reshape(Ysignal, 1); 

set(gca,'position',[0.01 0.03 .9 0.94],'units','normalized')
neuron.image(Y(:, ind_frame), [Ymin, Ymax]);
colorbar;
hold on;
plot(coor{1}(1,2:end), coor{1}(2,2:end), 'r', 'linewidth', 2); 
% plot([1,1,128, 128, 1], [129, 256, 256, 129, 129], '-.m'); 
axis equal off tight;
a = plot([220, 260]/pixel_size, 170*[1,1], 'w', 'linewidth', 10); 
b = text(220/pixel_size, 160, '40 um', 'color', 'w', 'fontsize', 18, 'fontweight', 'bold');

if export_fig
    saveas(gcf, sprintf('%s/example_frame.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_frame.pdf', output_folder));
end

figure('papersize', [d2+50, d1]/max(d1,d2)*5);
init_fig;
neuron.image(Ybg(:, ind_frame), [Ymin, Ymax]);
set(gca,'position',[0.01 0.03 .9 0.94],'units','normalized'); 
colorbar;
hold on;
plot(coor{1}(1,2:end), coor{1}(2,2:end), 'r', 'linewidth', 2); 
axis equal off tight;

if export_fig
    saveas(gcf, sprintf('%s/example_frame_bg.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_frame_bg.pdf', output_folder));
end

b0 = mean(Ybg,2); 
figure('papersize', [d2+50, d1]/max(d1,d2)*5);
init_fig;
neuron.image(Ybg(:, ind_frame)-b0); %, [-50, 150]);
set(gca,'position',[0.01 0.03 .9 0.94],'units','normalized'); 
colorbar;
hold on;
plot(coor{1}(1,2:end), coor{1}(2,2:end), 'r', 'linewidth', 2); 
axis equal off tight;

if export_fig
    saveas(gcf, sprintf('%s/example_frame_bg_fluc.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_frame_bg_fluc.pdf', output_folder));
end


figure('papersize', [d2+50, d1]/max(d1,d2)*5);
init_fig;
neuron.image(b0, [Ymin, Ymax]);
set(gca,'position',[0.01 0.03 .9 0.94],'units','normalized'); 
colorbar;
hold on;
plot(coor{1}(1,2:end), coor{1}(2,2:end), 'r', 'linewidth', 2); 
axis equal off tight;

if export_fig
    saveas(gcf, sprintf('%s/example_frame_bg_constant.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_frame_bg_constant.pdf', output_folder));
end


figure('papersize', [d2+50, d1]/max(d1,d2)*5);
init_fig;
neuron.image(neuron.A*neuron.C(:, ind_frame), [Yacmin, Yacmax]);
set(gca,'position',[0.01 0.03 .9 0.94],'units','normalized'); 
colorbar;
hold on;
plot(coor{1}(1,2:end), coor{1}(2,2:end), 'r', 'linewidth', 2); 
axis equal off tight;

if export_fig
    saveas(gcf, sprintf('%s/example_frame_ac.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_frame_ac.pdf', output_folder));
end

figure('papersize', [d2+50, d1]/max(d1,d2)*5);
init_fig;
neuron.image(Ysignal(:, ind_frame) - neuron.A*neuron.C(:, ind_frame), [-0.5, 0.5]*Yacmax);
set(gca,'position',[0.01 0.03 .9 0.94],'units','normalized')
hold on;
plot(coor{1}(1,2:end), coor{1}(2,2:end), 'r', 'linewidth', 2); 
axis equal off tight; colorbar;

if export_fig
    saveas(gcf, sprintf('%s/example_frame_res.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_frame_res.pdf', output_folder));
end;

%% variance reduced 
var_0 = var(double(Y), [], 2);  % variance in the data 
var_nobg = var(Ysignal,[],2); 
var_final = var(Ysignal-neuron.A*neuron.C, [], 2); 
% [u,s,v] = svdsecon(bsxfun(@minus, Ybg, mean(Ybg, 2)), 20); 
% var_rank1 = var(Y-u(:,1)*s(1)*v(:,1)', [],2); 
% var_rank2 = var(Y-u(:,1:2)*s(1:2,1:2)*v(:,1:2)', [], 2); 
% var_rank3 = var(Y-u(:,1:3)*s(1:3,1:3)*v(:,1:3)', [], 2); 
% var_rank5 = var(Y-u(:,1:5)*s(1:5,1:5)*v(:,1:5)', [], 2); 
% var_rank10 = var(Y-u(:,1:10)*s(1:10,1:10)*v(:,1:10)', [], 2); 

%%

figure('papersize', [6, 4]); 
init_fig; 
set(gcf,  'defaultAxesFontSize',16); 
set(gca, 'position', [0.15, 0.16, 0.84, 0.76]); 
v_alpha = 0.5; 
hold on ; 
dbin = 0.001; 
bins = 0:dbin:1; 
% variance explained by background 
[count, bins] = hist(1-var_nobg./var_0, bins); 
tmp_p = count/sum(count)/dbin; 
fill([bins, bins(end), bins(1)], [tmp_p, dbin, dbin],'b', 'facealpha', v_alpha, 'edgecolor', 'none');

% variance explained by the 1st PC of the background 
% [count, bins] = hist(1-var_rank1./var_0, 50); 
% fill([bins, bins(end), bins(1)], [count, 1,1],'m', 'facealpha', v_alpha, 'edgecolor', 'none');

% variance explained by 2nd-10th PCs of the background 
% [count, bins] = hist((var_rank1-var_rank3)./var_0, 50); 
% fill([bins, bins(end), bins(1)], [count, 1,1],'m', 'facealpha', v_alpha, 'edgecolor', 'none');

% variance explained by all other background components except the first 1 
% [count, bins] = hist((var_rank1-var_nobg)./var_0, 50); 
% fill([bins, bins(end), bins(1)], [count, 1,1],'g', 'facealpha', v_alpha, 'edgecolor', 'none');

% variance explained by neural signal
[count, bins] = hist((var_nobg-var_final)./var_0, bins); 
tmp_p = count/sum(count)/dbin; 
fill([bins, bins(end), bins(1)], [tmp_p, dbin, dbin], 'r', 'facealpha', v_alpha, 'edgecolor', 'none');

% variance in the residual 
[count, bins] = hist(var_final./var_0, bins); 
tmp_p = count/sum(count)/dbin; 
fill([bins, bins(end), bins(1)], [tmp_p, dbin, dbin],'g', 'facealpha', v_alpha, 'edgecolor', 'none');

box on; 
xlim([0, 1]); 
xlabel('Relative variance')
ylabel('Probability density'); 
breakxaxis([0.1, 0.85]); 
% legend('BG', '1st PC', 'BG without the 1st PC', 'denoised neural signal', 'residual'); 
legend('background', 'denoised neural signal', 'residual'); 

if export_fig && ~exist( sprintf('%s/variance_explained.pdf', output_folder), 'file')
    saveas(gcf, sprintf('%s/variance_explained.fig', output_folder) );
    saveas(gcf, sprintf('%s/variance_explained.pdf', output_folder));
end

%% compute correlation images 
create_correlation_images; 

%%  contours of the detected neurons, CNMF-E
neuron.Cn = Cn_filter;
neuron.PNR = PNR_filter;
if ~exist('Coor_cnmfe', 'var') || (length(Coor_cnmfe)~=size(neuron.A, 2))
    Coor_cnmfe = neuron.get_contours(0.6);
    neuron.Coor = Coor_cnmfe;
end
if ~exist('Coor_ica', 'var')|| (length(Coor_ica)~=size(neuron_ica.A, 2))
    Coor_ica = neuron_ica.get_contours(0.8);
    neuron_ica.Coor = Coor_ica;
end


%% contour plots of CNMF-E 
figure('papersize', [6, d2/d1*5]); 
init_fig; 
[~, srt] = sort(snr_cnmfe, 'descend'); 
plot_contours(neuron.A(:, srt), Cn_filter, 0.6, 0, [], Coor_cnmfe, 2); 
set(gca, 'position', [0.01, 0.02, 0.9, 0.96]); 

for m=(K_match+1):K_cnmfe
%     temp = Coor_cnmfe{ind_miss(m)}; 
    temp = Coor_cnmfe{m}; 
    fill(temp(1,2:end), temp(2,2:end), 'g', 'facealpha',0.3, 'edgecolor', 'none');
end 

colormap gray; axis  tight off equal; 
colorbar; 
if export_fig
    saveas(gcf, sprintf('%s/contours_cnmfe.fig', output_folder) );
    saveas(gcf, sprintf('%s/contours_cnmfe.pdf', output_folder));
    saveas(gcf, sprintf('%s/contours_cnmfe.eps', output_folder), 'psc2');
end

%% 
figure('papersize', [6, d2/d1*5]); 
init_fig; 
[~, srt]= sort(snr_ica, 'descend'); 
plot_contours(neuron_ica.A(:, srt), Cn_filter, 0.6, 0, [], Coor_ica, 2); 
set(gca, 'position', [0.01, 0.02, 0.9, 0.96]); 

colormap gray; axis tight off equal; 
colorbar; 
if export_fig
    saveas(gcf, sprintf('%s/contours_ica.fig', output_folder) );
    saveas(gcf, sprintf('%s/contours_ica.pdf', output_folder));
    saveas(gcf, sprintf('%s/contours_ica.eps', output_folder), 'psc2');
end

%% example of missed neuron 
T = size(neuron.C, 2);
figure('papersize', [13,1]);
init_fig;
ctr = neuron.estCenter();
K_show = 10; 
ind_miss = K_match+(1:10); 
%%
ctr = neuron.estCenter(); 
figure('papersize', [K_show,1]);
init_fig;
K_show = length(ind_miss);

for m=1:K_show
    axes('position', [(m-1)*1/K_show+0.001, 0.001, 1/K_show-0.001, 0.98]);
    r0 = round(ctr(ind_miss(m), 1));
    c0 = round(ctr(ind_miss(m), 2));
    img = neuron.reshape(neuron.A(:, ind_miss(m)),2);
    if r0<23
        r0 = 23;
    elseif r0>=d1-18
        r0 = d1-18;
    end
    if c0<21
        c0 = 21;
    elseif c0>=d2-20
        c0 = d2-20;
    end
    imagesc(img(r0+(-22:18), c0+(-20:20)));
    
    axis equal off tight;
    text(1,6, num2str(m), 'color', 'w', 'fontweight', 'bold', 'fontsize', 15);
end
if export_fig
    saveas(gcf, sprintf('%s/ica_missed_spatial.fig', output_folder) );
    saveas(gcf, sprintf('%s/ica_missed_spatial.pdf', output_folder));
end

% temporal
figure('papersize', [K_show+1, 4.2]);
init_fig;
set(gcf, 'defaultAxesFontSize', 16);
col = colormap(cool);
C = neuron.C_raw(ind_miss(1:K_show),:);
axes('position', [0.0, 0.0, 0.95, 1]); hold on;
for m=1:K_show
    y = C(m,:);
    plot((1:T)/neuron.Fs, 1.2*y/max(y)+K_show-m,'linewidth', 1, 'color', [1,1,1]*0.3);
    text(-10-2*(m>=10), (K_show-m), num2str(m), 'fontsize', 20);
end
plot([290,300], [-0.5, -0.5], 'k', 'linewidth', 5);
% text(289, -1, '10 sec', 'fontsize', 14);
axis off;
axis([-20,300,-1.5, K_show]);
if export_fig
    saveas(gcf, sprintf('%s/ica_missed_temporal.fig', output_folder) );
    saveas(gcf, sprintf('%s/ica_missed_temporal.pdf', output_folder));
end

%% example of matched neurons 
% remove ICA neurons whose SNRs are too small 
neuron_ica = neuron_ica_bk.copy(); 
A_ica_before_trim = A_ica_before_trim_bk; 

snr_ica = var(neuron_ica.C, 0, 2)./var(neuron_ica.C_raw-neuron_ica.C, 0, 2); 

%% match neurons 
match_cnmfe = pair_neurons(neuron.A, neuron.C_raw, neuron_ica.A, neuron_ica.C_raw); 

ids_match = find(~isnan(match_cnmfe.ind_max)); 
ids_match(match_cnmfe.max_spatial(ids_match)<0.5) = []; 
ids_ica = match_cnmfe.ind_max(ids_match); 
K_match = length(ids_match); 

ind = 1:size(neuron.A,2); 
ind(ids_match) = []; 
srt = [ids_match, ind]; 
neuron.orderROIs(srt); 
snr_cnmfe = snr_cnmfe(srt); 

ind = 1:size(neuron_ica.A, 2); 
ind(ids_ica) = []; 
srt = [ids_ica, ind]; 
neuron_ica.orderROIs(srt); 
snr_ica = snr_ica(srt); 
A_ica_before_trim = A_ica_before_trim(:, srt);


pixels = [22685, 13072, 20542, 17444, 14399, 14768, 17993, 23485, 21037, 15254]; %
ind_match = zeros(length(pixels), 1); 
A = neuron.A; 
A = bsxfun(@times, A, 1./max(A, [],1)); 
for m=1:length(pixels)
    temp = A(pixels(m),:); 
    [~, ind_match(m)] = max(temp); 
end
ids_match = ind_match; 
% ind_match = sort(ind_match); 

ids_ica =ids_match; 
ctr = neuron.estCenter(); 
ctr_ica =  neuron_ica.estCenter(); 

%% plot SNRs
figure('papersize', [3.5,5]); 
init_fig; 
set(gcf, 'defaultAxesFontSize', 14); 
plot(snr_ica(1:K_match),snr_cnmfe(1:K_match),  '.k', 'markersize', 10); 
hold on; 
for m=1:length(ids_match)
    plot(snr_ica(ids_ica(m)), snr_cnmfe(ids_match(m)), 'o', ...
        'markersize', 10, 'markerfacecolor', col(64-4*m, :), 'markeredgecolor', 'none'); 
end 
set(gca, 'position', [0.23, 0.15, 0.72, 0.83]); 
hold on 
axis  tight; 

xlim([0.2, max(snr_ica(1:K_match))*1.1]); 
ylim([0.2, max(snr_cnmfe(1:K_match))*1.1]); 
ylabel('CNMF-E'); 
xlabel('PCA/ICA'); 
set(gca, 'xscale', 'log')
set(gca, 'yscale', 'log')
set(gca, 'xtick', 1:10:100); 
set(gca, 'ytick', 10.^(-1:2)); 

plot(get(gca, 'xlim'), get(gca, 'xlim'), '-r'); hold on; 
if export_fig
    saveas(gcf, sprintf('%s/snr_pca_ica.fig', output_folder) );
    saveas(gcf, sprintf('%s/snr_pca_ica.pdf', output_folder));
end
%% temporal 
figure('papersize', [7.0, 6.5]); 
init_fig; 
set(gcf, 'defaultAxesFontSize', 16); 
col = colormap(cool); 
t_ind = 1:4500; 
C = neuron.C_raw(ids_ica(1:10),t_ind);  
axes('position', [0.0, 0.0, 0.99, 1]); hold on; 
for m=1:10 
    y = C(m,:); 
    plot(t_ind/neuron.Fs, y/max(y)+10-m,'linewidth', 1, 'color', col(64-4*m,:)); 
    text(-5-1.5*(m==10), (10-m), num2str(m), 'fontsize', 20); 
end 
plot([80,100], [-0.5, -0.5], 'k', 'linewidth', 5); 
% text(86, -1, '10 sec', 'fontsize', 18); 
axis off; 
axis([-8,100,-1.5, 10.5]); 

if export_fig
    saveas(gcf, sprintf('%s/matched_temporal_cnmfe.fig', output_folder) );
    saveas(gcf, sprintf('%s/matched_temporal_cnmfe.pdf', output_folder));
end
% PCA/ICAfigure('papersize', [6.5, 4]); 
figure('papersize', [7.0, 6.5]); 
init_fig; 
set(gcf, 'defaultAxesFontSize', 16); 
col = colormap(cool); 
t_ind = 1:4500; 
C = neuron_ica.C_raw(ids_ica(1:10),t_ind);  
axes('position', [0.0, 0.0, 0.99, 1]); hold on; 
for m=1:10 
    y = C(m,:); 
    plot(t_ind/neuron.Fs, y/max(y)+10-m,'linewidth', 1, 'color', col(64-4*m,:)); 
%     text(-24-1.5*(m==10), (10-m), num2str(m), 'fontsize', 20); 
end 
plot([80,100], [-0.5, -0.5], 'k', 'linewidth', 5); 
% text(87, -1, '10 sec', 'fontsize', 18); 
axis off; 
axis([-8,100,-1.5, 10.5]); 

if export_fig
    saveas(gcf, sprintf('%s/matched_temporal_ica.fig', output_folder) );
    saveas(gcf, sprintf('%s/matched_temporal_ica.pdf', output_folder));
end
%% spatial 
% CNMF-E 
figure('papersize', [2, 5]);
init_fig;
for m=1:10
    axes('position', [0.505-0.5*mod(m,2), 1.003-ceil(m/2)*0.2, 0.49,0.196]);
    r0 = round(ctr(ids_match(m), 1));
    c0 = round(ctr(ids_match(m), 2));
    if r0<23
        r0 = 23;
    elseif r0>=d1-18
        r0 = d1-18;
    end
    if c0<21
        c0 = 21;
    elseif c0>=d2-20
        c0 = d2-20;
    end
    img = neuron.reshape(neuron.A(:, ids_match(m)),2);

    temp = img(r0+(-22:18), c0+(-20:20)); 
    imagesc(temp/max(temp(:)), [0,1]);    
    axis equal off tight;
    text(1, 6 , num2str(m), 'color', 'w', 'fontweight', 'bold', 'fontsize', 20);
end
if export_fig
    saveas(gcf, sprintf('%s/match_spatial_cnmfe.fig', output_folder) );
    saveas(gcf, sprintf('%s/match_spatial_cnmfe.pdf', output_folder));
end

% PCA/ICA 
figure('papersize', [2, 5]);
init_fig;
for m=1:10
    axes('position', [0.505-0.5*mod(m,2), 1.003-ceil(m/2)*0.2, 0.49,0.196]);
    r0 = round(ctr(ids_match(m), 1));
    c0 = round(ctr(ids_match(m), 2));
    if r0<23
        r0 = 23;
    elseif r0>=d1-18
        r0 = d1-18;
    end
    if c0<21
        c0 = 21;
    elseif c0>=d2-20
        c0 = d2-20;
    end
    img = neuron.reshape(A_ica_before_trim(:, ids_ica(m)), 2); 

    temp = img(r0+(-22:18), c0+(-20:20)); 
    imagesc(temp/max(temp(:)), [-0.3,1]);    
    axis equal off tight;
    text(1, 6, num2str(m), 'color', 'w', 'fontweight', 'bold', 'fontsize', 20);
end
if export_fig
    saveas(gcf, sprintf('%s/match_spatial_ica.fig', output_folder) );
    saveas(gcf, sprintf('%s/match_spatial_ica.pdf', output_folder));
end
%%
figure('papersize', [2, 2]); 
init_fig;
axes('position', [0.05, 0.1, 0.9, 1]);
imagesc([], [-0.3, 1.0]); 
colorbar('southoutside');  set(gca, 'fontsize', 25); 
axis off; 
saveas(gcf, sprintf('%s/colorbar_ica.fig', output_folder)); 
saveas(gcf, sprintf('%s/colorbar_ica.pdf', output_folder)); 

%%
figure('papersize', [2, 2]); 
init_fig;
axes('position', [0.05, 0.1, 0.9, 1]);
imagesc([], [0, 1.0]); 
colorbar('southoutside');  set(gca, 'fontsize', 25); 
axis off; 
saveas(gcf, sprintf('%s/colorbar_cnmfe.fig', output_folder)); 
saveas(gcf, sprintf('%s/colorbar_cnmfe.pdf', output_folder)); 

%% 
[~, id1] = max(neuron.A(sub2ind([d1, d2], 111, 130), :)); 
[~, id2] = max(neuron.A(sub2ind([d1, d2], 106, 122), :)); 
[~, id3] = max(neuron.A(sub2ind([d1, d2], 117, 115), :)); 

ids = [id1, id2, id3];  
% ids = [8,35,50]; 
ica_ids = ids;
gSiz  = neuron.options.gSiz; 
ctr = neuron.estCenter(); 
tmp_ctr = mean(ctr(ids, :)); 
% determine the spatial range 
temp = neuron.reshape(sum(neuron.A(:, ids), 2), 2);
[tmp_r, tmp_c] = find(temp>1e-2);
xmin = tmp_ctr(2)-gSiz*1.5;
xmax = tmp_ctr(2)+gSiz*1.5;
ymin = tmp_ctr(1)-gSiz*1.5;
ymax = tmp_ctr(1)+gSiz*1.5;
x_center = round(xmin/2+xmax/2);
y_center = round(ymin/2+ymax/2);
ctr = sub2ind([d1,d2], y_center, x_center);

% pca/ica
figure('papersize', [(xmax-xmin+1),(ymax-ymin+1)]*0.1);
init_fig;
temp = neuron_ica.A; 
temp(temp<0) = 0; 
img = temp(:, ica_ids); 
img =bsxfun(@times, img, 1./max(img, [], 1)); 
img = neuron.reshape(img, 2);
for m=1:3
    if isnan(ica_ids(m))
        img(:, :, m) = 0;
    end
end
img(img<0) = 0;
imagesc(img/max(img(:)));
axis equal off;
set(gca, 'position', [0, 0, 1, 1]); hold on; 

axis([xmin, xmax, ymin, ymax]);
if export_fig
    saveas(gcf, sprintf('%s/example_spatial_ica.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_spatial_ica.pdf', output_folder));
end

% pca/ica, temporal 
figure('papersize', [10, 2.5]);
init_fig;
axes('position', [0.05, 0.05, 0.9, 0.9]); hold on;
C_ica = neuron_ica.C_raw; 
if ~isnan(ica_ids(1))
    y = C_ica(ica_ids(1), :);
    plot(y/max(y)+1, 'r');
end

if ~isnan(ica_ids(2))
    y = C_ica(ica_ids(2), :);
    plot(y/max(y)+2, 'g');
end

if ~isnan(ica_ids(3))
    y = C_ica(ica_ids(3), :);
    plot(y/max(y)+3 , 'b');
end
axis off;
xlim([200*neuron.Fs, 600*neuron.Fs]); 
ylim([0.5, 4]); 
plot([580,600]*neuron.Fs, [0.8, 0.8], 'k', 'linewidth', 6); 
% text(561*neuron.Fs, 0.56, '40 sec', 'fontsize', 18); 
%highlight some time interval 
t1 = [3492, 4104, 4174, 4702,4977,5438]; 
t2 =  8095; 
for m=1:length(t1); 
    x = t1(m); 
    fill(x+[-15, 15, 15, -15, -15]*3, [0.9, 0.9, 4.0, 4.0, 0.9], 'y',...
        'facealpha', 0.3, 'edgecolor', 'none'); 
end 
 fill(t2+[-15, 15, 15, -15, -15]*6, [0.9, 0.9, 4.0, 4.0, 0.9], 'c',...
        'facealpha', 0.3, 'edgecolor', 'none'); 
axis off; 
if export_fig
    saveas(gcf, sprintf('%s/example_temporal_ica.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_temporal_ica.pdf', output_folder));
end

%% CNMF-E
figure('papersize', [(xmax-xmin+1),(ymax-ymin+1)]*0.1);
init_fig;
axes('position', [0, 0, 1, 1]);
img = neuron.A(:, ids); 
img =bsxfun(@times, img, 1./max(img, [], 1)); 
img = neuron.reshape(img, 2);
imagesc(img/max(img(:)));
axis([xmin, xmax, ymin, ymax]);

if export_fig
    saveas(gcf, sprintf('%s/example_spatial_cnmfe.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_spatial_cnmfe.pdf', output_folder));
end
%
figure('papersize', [10,2.5]);
init_fig;
axes('position', [0.05, 0.05, 0.9, 0.9]); hold on;
y1 = neuron.C_raw(ids(1), :);
y = neuron.C(ids(1), :);
plot(y1/max(y1)+1, 'r', 'linewidth', 2);
% plot(y/max(y)+1.6, 'r');

y1 = neuron.C_raw(ids(2), :);
y = neuron.C(ids(2), :);
plot(y1/max(y1)+2, 'g', 'linewidth', 2);
% plot(y/max(y)+0.8, 'b');

y1 = neuron.C_raw(ids(3), :);
y = neuron.C(ids(3), :);
plot(y1/max(y1)+3, 'b', 'linewidth', 2);
% plot(y/max(y) , 'g');

axis off;
xlim([200*neuron.Fs, 600*neuron.Fs]); 
ylim([0.5, 4]); 
plot([580,600]*neuron.Fs, [0.8, 0.8], 'k', 'linewidth', 6); 
% text(561*neuron.Fs, 0.56, '40 sec', 'fontsize', 18); 

%highlight some time interval 
t1 = [3492, 4104, 4174, 4702,4977,5438]; 
t2 =  8095; 
for m=1:length(t1); 
    x = t1(m); 
    fill(x+[-15, 15, 15, -15, -15]*3, [0.9, 0.9, 4.0, 4.0, 0.9], 'y',...
        'facealpha', 0.3, 'edgecolor', 'none'); 
end 
 fill(t2+[-15, 15, 15, -15, -15]*6, [0.9, 0.9, 4.0, 4.0, 0.9], 'c',...
        'facealpha', 0.3, 'edgecolor', 'none'); 
if export_fig
    saveas(gcf, sprintf('%s/example_temporal_cnmfe.eps', output_folder), 'psc2');
    saveas(gcf, sprintf('%s/example_temporal_cnmfe.pdf', output_folder));
end

%% save video
create_overlapping_video; 






