function [Data] = GPIB_control(compliance, primary_address, start, stop, step, delay,testname)
    %Unit = GPIB_control(A, 16, V, V, V, ms,'name_file.txt')
    % GPIB_control: Controls a dual sweep on Keithley 236 SMU remotely,
    % default is to source V and measure I.
    % Input arguments:
    % Compliance(floating point number) = maximum value of current (or voltage) to be measured,
    % Primary_address = primary address of the instrument (displayed when
    % the instrument starts up, but can also be found in Instrument Control
    % Toolbox. Default=16
    % Start(floating point number) = start value of the sweep
    % Stop(floating point number) = end(or maximum if dual sweep) value of the sweep
    % Step(floating point) = step between each value in the sweep
    % Delay = the time before each measurement. Default is in ms.
    % Testname = filename using within code and where measured data is stored, input as a .txt filename eg.
    % 'test1_270723.txt'
    % Outputs:
    % testname = output file with measured data (default)
    % Figure 1 = I-V scatter plot
    % Figure 2 = log(abs(I))-V scatter plot


    instrreset
    
    %Opening communication with device:
    keith236 = instrfind('Type', 'gpib', 'BoardIndex', 'PrimaryAdress', 'Tag', ''); %sets instrument
    if isempty(keith236)
        keith236 = gpib('NI', 0, primary_address);
        keith236.Timeout = 1000; %Can increase timeout value for longer measurements
    else
        fclose(keith236);
        keith236 = keith236(1);
    end
    fopen(keith236); %opens communication with device
    
    fprintf(keith236, 'F0,1X'); %source V, measure I, sweep
    %F0,0X = source V, measure I, DC
    %F0,1X = source V, measure I, sweep
    %F1,0X = source I, measure V, DC
    %F1,1X = source I, measure V, DC

    %Input character array for compliance command - just some formatting to
    %allow for arbitrary input variables
    x='L';
    z=num2str(compliance);
    t=',';
    u='0X';
    compliance_in = strcat(x,z,t,u);
    %Formatting for sweep command
    a='Q1';
    b=',';
    c=num2str(start);
    d=',';
    e=num2str(stop);
    f=',';
    g=num2str(step);
    h=',';
    i=num2str(0);
    j=',';
    k=num2str(delay);
    l='Q7';
    m=num2str(-step);
    in = strcat(a,b,c,d,e,f,g,h,i,j,k);
    back = strcat(l,b,e,d,c,f,m,h,i,j,k);


    fprintf(keith236, in);%LINEAR SWEEP from start to stop, step, range = default, delay
    fprintf(keith236, 'B0,0,X'); %Applies a bias voltage of 0V
    fprintf(keith236, back); %Second half of dual sweep in opposite direction from stop to start, same step, range and delay as abovr
    
    fprintf(keith236, compliance_in); %Setting the compliance value
    fprintf(keith236, 'T1,0,0,0X'); %Triggering, origin  = IEEE GET, continuous, end = no output trigger, end = disabled
    fprintf(keith236, 'N1X');%Turns output on
    fprintf(keith236, 'G4,2,2X'); %Output data format, 5 = source+ measure values, 1=source, 4=measure

    [Data] = query(keith236, 'H0X'); %Retrieving the data from the instrument, triggers over IEEE bus
    fprintf(keith236, 'N0X'); %Puts the instrument back to standby

    %%Plotting data;
    filename = testname;  
    fid = fopen(filename,'wt'); % open file for writing (overwrite if necessary)
    fprintf(fid,'%s',Data); % Write the char array, interpret newline as new line
    fclose(fid);
    data=importdata(filename); %Importing measured data
    I=data(1,:);
    V1=start:step:stop;%Setting voltage arrays
    V2 = stop:-step:start;
    V=cat(2,V1,V2); %Voltage array for dual sweep (forwards and backwards)
    y=abs(I);
    y=log10(y);
    figure
    scatter(V, I); %I-V scatter plot
    xlabel('Voltage(V)') 
    ylabel('Current(A)')
    figure
    scatter(V, y) %Log(I)-V plot
    xlabel('Voltage(V)')
    ylabel('log_{10}(|Current|)')
    %Extracting the current and voltage data to a txt file
    A=[V;I]; %Creates a 2D array of the voltage and current values
    A=A'; %Transposes array so that when it is converted to a table and text file it is the correct way round
    T=array2table(A, 'VariableNames',{'Voltage(V)', 'Current(A)'}); %Converts array to table with headers
    writetable(T, testname, 'Delimiter','\t') %Converts table to .txt file with tab delimiters
    fclose(keith236); % closes communication with the instrument and ends control sequence
end

