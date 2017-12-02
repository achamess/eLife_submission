%% data preparation
Yac = neuron.reshape(neuron.A*neuron.C, 2);
Ybg = neuron.reshape(Ybg, 2);
Ysignal = neuron.reshape(Ysignal, 2);
figure('position', [0,0, 600, 400]);

if ~exist('range_ac', 'var')
    center_ac = median(max(neuron.A,[],1)'.*max(neuron.C,[],2))/2;
    range_res = [-1,1]*center_ac;
    range_ac = center_ac+range_res;
    multi_factor = 4;
    center_Y = min(Y(:)) + multi_factor*center_ac;
    range_Y = center_Y + range_res*multi_factor;
end
%% create avi file
if save_avi
    if ~exist('avi_filename', 'var')
        avi_filename =[dir_nm, filesep, file_nm];
    end
    avi_file = VideoWriter(avi_filename);
    if ~isnan(neuron.Fs)
        avi_file.FrameRate= neuron.Fs/kt;
    end
    avi_file.open();
end

%% add pseudo color to denoised signals
% [K, T]=size(neuron.C);
% % draw random color for each neuron
% % tmp = mod((1:K)', 6)+1;
% Y_mixed = zeros(neuron.options.d1*neuron.options.d2, T, 3);
% temp = prism;
% % temp = bsxfun(@times, temp, 1./sum(temp,2));
% col = temp(randi(64, K,1), :);
% for m=1:3
%     Y_mixed(:, :, m) = neuron.A* (diag(col(:,m))*neuron.C);
% end
% Y_mixed = uint16(Y_mixed/(1*center_ac)*65536);
%% play and save
ax_y =   axes('position', [0.015, 0.51, 0.3, 0.42]);
ax_bg=   axes('position', [0.015, 0.01, 0.3, 0.42]);
ax_signal=    axes('position', [0.345, 0.51, 0.3, 0.42]);
ax_denoised =    axes('position', [0.345, 0.01, 0.3, 0.42]);
ax_res =    axes('position', [0.675, 0.51, 0.3, 0.42]);
ax_mix =     axes('position', [0.675, 0.01, 0.3, 0.42]);
for m=t_begin:kt:t_end
    axes(ax_y); cla; 
    imagesc(Ybg(:, :,m)+Ysignal(:, :, m), range_Y);
    %     set(gca, 'children', flipud(get(gca, 'children')));
    title('Raw data');
    axis equal off tight;
    
    axes(ax_bg); cla; 
    imagesc(Ybg(:, :, m),range_Y);
    %     set(gca, 'children', flipud(get(gca, 'children')));
    axis equal off tight;
    title('Background');
    
    axes(ax_signal); cla; 
    imagesc(Ysignal(:, :, m), range_ac); hold on;
    %     set(gca, 'children', flipud(get(gca, 'children')));
    title(sprintf('(Raw-BG) X %d', multi_factor));
    axis equal off tight;
    
    axes(ax_denoised); cla; 
    imagesc(Yac(:, :, m), range_ac);
    %     imagesc(Ybg(:, :, m), [-50, 50]);
    title(sprintf('Denoised X %d', multi_factor));
    axis equal off tight;
    
    axes(ax_res); cla; 
    imagesc(Ysignal(:, :, m)-Yac(:, :, m), range_res);
    %     set(gca, 'children', flipud(get(gca, 'children')));
    title(sprintf('Residual X %d', multi_factor));
    axis equal off tight;
    %         subplot(4,6, [5,6,11,12]+12);
    
    axes(ax_mix); cla;
    imagesc(neuron.reshape(A*C(:,m),2), range_ac);  hold on;
    title(sprintf('True signals X %d', multi_factor));
    text(1, 10, sprintf('Frame: %d', m), 'color', 'w', 'fontweight', 'bold');
    
    axis equal tight off;
    %     box on; set(gca, 'xtick', []);
    %     set(gca, 'ytick', []);
    drawnow; 
    if save_avi
        temp = getframe(gcf);
        temp = imresize(temp.cdata, [400, 600]);
        avi_file.writeVideo(temp);
    end
end

if save_avi
    avi_file.close();
end
