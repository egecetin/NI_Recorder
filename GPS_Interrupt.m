function GPS_Interrupt(~,event,handles)

    buff=fgetl(handles.gps);
    if strcmp(buff(2:6),'GPGLL') && strcmp(buff(40),'A')
        handles.GPStime=[buff(33:34) ':' buff(35:36) ':' buff(37:38)];
        system(['time ' handles.GPStime]);

        handles.location.lat=buff(8:18);
        handles.location.lon=buff(20:31);
        
        fprintf(handles.logger,['GPS' datestr(datetime('now'),'yyyy.mm.dd HH:MM:SS') ' \n']);
    elseif strcmp(buff(2:6),'GPRMC') && strcmp(buff(15),'A')
        system(['date ' buff(54:55) '-' buff(56:57) '-' buff(58:59)]);
    else
        fprintf(handles.logger,['No GPS ' datestr(datetime('now'),'yyyy.mm.dd HH:MM:SS') ' \n']);
    end
end

