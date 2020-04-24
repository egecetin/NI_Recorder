function [ui, handles]=maincalc(event, handles)
    persistent databuff freqbuff local oldtimer filetimer filelist
    if isempty(databuff) % Sadece ilk çaðýrmada boþ olacak
        % - Init variables
        sizes=get(groot,'Screensize');
        oldtimer=0;
        databuff=zeros(handles.fs*handles.time*handles.maxstep,handles.nchannel);
        for i=1:handles.maxstep
            timelabels{i}=num2str(-handles.time*(handles.maxstep-i));
            timeticks(i)=handles.fs*handles.time*i;
        end

        % - Init GUI
        local.f=uifigure('Name','Data Acquisition','Visible','off', ...
            'Position',[50 50 sizes(3)*0.8 sizes(4)*0.8],'WindowState','normal','Scrollable','on');
        ui=local.f;
        local.status=local.f.Name;
        for i=1:handles.nchannel
            % - Time data plot
            local.axes{handles.nchannel-i+1,1}=uiaxes('Parent',local.f, ...
                'Position',[15 20+sizes(4)*0.25+(i-1)*sizes(4)*0.48 sizes(3)*0.97 sizes(4)*0.23],'Color','none');
            plot(local.axes{handles.nchannel-i+1,1},databuff(:,i));
            disableDefaultInteractivity(local.axes{handles.nchannel-i+1,1});
            local.axes{handles.nchannel-i+1,2}=uiaxes('Parent',local.f, ...
                'Position',[15 20+(i-1)*sizes(4)*0.48 sizes(3)*0.97 sizes(4)*0.23],'Color','none');

            % - Set limits and labels
            xticks(local.axes{handles.nchannel-i+1,1},timeticks);
            xticklabels(local.axes{handles.nchannel-i+1,1},timelabels);
            xlim(local.axes{handles.nchannel-i+1,1},[0 handles.fs*handles.time*handles.maxstep]);
            title(local.axes{handles.nchannel-i+1,1},['Channel ' num2str(handles.nchannel-i)]);

            xticks(local.axes{handles.nchannel-i+1,2},timeticks);
            xticklabels(local.axes{handles.nchannel-i+1,2},timelabels);
            ylim(local.axes{handles.nchannel-i+1,2},[0 handles.fs/2]);

            % - Init freq
            freqbuff{i}=zeros(handles.wlen/2+1,floor((handles.fs*handles.time*handles.maxstep-handles.wlen)/(handles.wlen-handles.overlap))+1);
            imagesc(local.axes{handles.nchannel-i+1,2},'XData',handles.wlen/(2*handles.fs):(handles.wlen-handles.overlap)/handles.fs:length(databuff(:,i))/handles.fs, ...
                'YData',0:handles.fs/handles.wlen:handles.fs/2,'CData',min(max(freqbuff{i},handles.dBlim),0),[handles.dBlim 0]);
            colormap(local.axes{handles.nchannel-i+1,2},handles.map);
            axis(local.axes{handles.nchannel-i+1,2},'tight');
            disableDefaultInteractivity(local.axes{handles.nchannel-i+1,2});
        end

        if handles.filestat
            dstr=datestr(datetime('now'),'yyyymmddHHMM');
            fullpath=[handles.root '\' dstr(1:4) '\' dstr(5:6) '\' dstr(7:8) '\' dstr(9:10) '\' dstr(1:8) '_' dstr(9:12)];
            mkdir(fullpath(1:end-13));
            for i=1:handles.nchannel
                filelist{i}=fopen([fullpath '_Ch' num2str(i-1) '.txt'],'W');
                dstr=datestr(datetime('now'),'yyyy.mm.dd HH:MM:SS');
                fprintf(filelist{i},'%s %s %d\n',['Ch' num2str(i)],dstr,handles.fs);
            end
        end

        % Set GUI visible
        local.f.Visible='on';
        drawnow;
        filetimer=datetime('now');
        return;
    end

    % - Write
    if handles.filestat
        for i=1:handles.nchannel
            writer=cellstr(compose('%d',event.Data(:,i)));
            fprintf(filelist{i},'%s\n',writer{:});
        end
        datenow=datetime('now')-filetimer;
        if datenow>handles.timelimit
            filetimer=datetime('now');
            dstr=datestr(datetime('now'),'yyyymmddHHMM');
            fullpath=[handles.root '\' dstr(1:4) '\' dstr(5:6) '\' dstr(7:8) '\' dstr(9:10) '\' dstr(1:8) '_' dstr(9:12)];
            mkdir(fullpath(1:end-13));
            for i=1:handles.nchannel
                fclose(filelist{i});
                pause(0.001);
                filelist{i}=fopen([fullpath '_Ch' num2str(i-1) '.txt'],'W');
                dstr=datestr(datetime('now'),'yyyy.mm.dd HH:MM:SS');
                fprintf(filelist{i},'%s %s %d\n',['Ch' num2str(i)],dstr,handles.fs);
            end
        end
    end
    % - Merge event.Data
    databuff(1:handles.fs*handles.time*(handles.maxstep-1),:)=databuff(handles.fs*handles.time+1:end,:);
    databuff(handles.fs*handles.time*(handles.maxstep-1)+1:end,:)=event.Data(:,:);

    % - Plot data
    ylimit=(max(max(abs(databuff-mean(databuff)))));
    for i=1:handles.nchannel
        k=floor(size(freqbuff{i},2)/handles.maxstep*(handles.maxstep-1)+1);

        freqbuff{i}(:,1:k)=freqbuff{i}(:,floor(size(freqbuff{i},2)/handles.maxstep)+1:end);
        % Normalize edilmeli NI çýktý aralýðý gerekiyor
        buff=databuff(handles.fs*handles.time*(handles.maxstep-1)+1-handles.wlen+handles.overlap:end,i);
        for j=1:handles.wlen-handles.overlap:length(buff)-handles.wlen
            afft=abs(fft(buff(j:j+handles.wlen-1).*hann(handles.wlen)./handles.wlen,handles.wlen));
            freqbuff{i}(:,k)=20*log10(afft(1:handles.wlen/2+1));
            k=k+1;
        end

        % - Update axes
        local.axes{i,1}.YLim=[-ylimit ylimit];
        local.axes{i,1}.Children.YData=databuff(:,i)-mean(databuff(:,i));
        local.axes{i,2}.Children.CData=freqbuff{i};
    end

    % - Check time
    timer=toc();
    if timer-oldtimer>handles.time*1.15
        local.status=['Warning!!! Loop time: ' num2str(timer-oldtimer) ' sec. Data loss may occur.'];
    else
        local.status='Data Acquisition';
    end
    oldtimer=timer;
end