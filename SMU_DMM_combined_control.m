function SMU_DMM_combined_control(compliance, start, stop, step, delay, gain, testname)
    
    %Function used to control a Keithley 236 source-measure unit and
    %Thurlby-Thandar Instruments 1705 digital multimeter via GPIB and record
    %I-V measurements

    %Unit =SMU_DMM_combined_control(A, V, V, V, ms,,'name_file.txt')

    % Input arguments:
    % Compliance(floating point number) = maximum value of current (or voltage) to be measured,
    % Start(floating point number) = start value of the sweep
    % Stop(floating point number) = maximum value of the dual sweep
    % Step(floating point) = step between each value in the sweep
    % Delay = the time between each measurement
    % Testname = filename using within code and where measured data is stored, input as a .txt filename eg.
    % 'test1_270723.txt'
    % Outputs:
    % testname = output file with measured data (default)
    % Subplot 1 = I-V_meas scatter plot
    % Subplot 2 = log(abs(I))-V_meas scatter plot
    % Subplot 3 = R-V_bias scatter plot
    %Emma Horgan, August 2023
    
    instrreset %Resetting all instruments
    
    %DO NOT TOUCH CODE BELOW THIS POINT!
    
    %Connecting with instruments and establishing basic parameters
    
    
    %Connecting with Keithley 236 SMU
    keith236 = instrfind('Type', 'gpib', 'BoardIndex', 'PrimaryAdress', 'Tag', ''); %Sets instrument
        if isempty(keith236)
            keith236 = gpib('NI', 0, 16); %Sets instrument object in code
            keith236.Timeout = 1000; %Timeout value of instrument object, maximum =1000
        else
            fclose(keith236);
            keith236 = keith236(1);
        end
    fopen(keith236); %Opens communication with SMM
    
    %Connecting with Tti 1705 DMM
    dmm1705 = instrfind('Type', 'gpib', 'BoardIndex', 'PrimaryAdress', 'Tag', ''); %Sets instrument
    if isempty(dmm1705)
        dmm1705 = gpib('NI', 0, 1); %Sets instrument object in code
        dmm1705.Timeout = 1000; %Timeout value of instrument object
        fclose(dmm1705);
        dmm1705 = dmm1705(1);
    end
    fopen(dmm1705); %Opens communication with DMM
    
    
    
    %Setting up basic parameters and configurations of SMU
    fprintf(keith236, 'F0,0X'); %Setting SMU to source V and measure I, DC
    
    
    %Formatting for compliance command input string
    x='L';
    z=num2str(compliance);
    t=',';
    u='0X';
    compliance_in = strcat(x,z,t,u);
    %Setting the compliance current of the SMU with auto range (0)
    fprintf(keith236, compliance_in );
    fprintf(keith236, 'T1,0,0,0X'); %Triggering(T), origin  = IEEE GET(1), continuous - no trigger needed to contiue source and measurent cycles (0), end = no output trigger, end = trigger disabled 
    
    
    %Setting the output data format
    fprintf(keith236, 'G4,2,0X'); % Returns measure value (4), ASCII data, no prefix or suffix (2), one line of dc data per talk (0)
    
    
    %Setting up basic configuration of DMM
    fprintf(dmm1705, 'VDC'); %Setting it to measure DC voltage 
    fprintf(dmm1705, 'AUTO'); %Setting the range to adjust automatically when needed
    
    
    
    
    %Taking measurements:
    %Creating array of applied voltages
    V_app_forward=start:step:stop;
    V_app_backward=stop:-step:start;
    V_app=cat(2,V_app_forward, V_app_backward); %Joins the forward and back voltage sweep arrays together
    
    %Setting empty arrays for measured data to be stored in
    V_meas=[];
    I_meas=[];
    
    fprintf(keith236, 'N1X'); %Turns the output of the SMU on, 1=ON, 0=OFF
    
    %Looping through all applied voltages and measuring V from DMM and 
    % I from SMU
    for i=1 :length(V_app)
        %Formatting for input of applied DC voltage
        a='B';
        b=num2str(V_app(i));
        c=',0,';
        d=num2str(delay);
        e='X';
        bias = strcat(a,b,c,d,e);
        fprintf(keith236, bias); %Applying ith element of applied voltage array, delay before applying it specified at top of code, autorange
        I_meas_new=query(keith236, 'H0X'); %Triggering the SMU to send the current reading
        V_meas_new=query(dmm1705, 'READ?'); %Triggering the DMM to send the voltage reading
        I_meas_new = str2double(I_meas_new); %Converting measured current to a double
        I_meas= [I_meas,I_meas_new]; %Adding measured value to the current array which stores all measured values
        V_meas_new_2 = extractBetween(V_meas_new, 1,10); %Extracting voltage values (removing unncessary characters in the string) and extracting only the numerical measured value
        %Converting between data types in matlab
        V_meas_new_2 = cell2mat(V_meas_new_2); 
        V_meas_new_2=str2double(V_meas_new_2);
        V_meas = [V_meas, V_meas_new_2]; %Adding measured value to the measured voltage array
    end
    
    
    
    V_meas = V_meas/gain; % Getting the original measured voltage value before amplification of the signal
    fprintf(keith236, 'B0,0,0X'); %Setting the SMU to apply 0V immediately 
    fprintf(keith236, 'N0X'); %Turning off the output of the SMU
    
    
    %Initial plotting:
    
    %I_meas vs V_meas
    subplot(2,2,1)
    scatter(V_meas,I_meas) 
    xlabel('V_{meas}(V)')
    ylabel('I_{meas}(A)')
    
    %Semi log plot
    y=log10(abs(I_meas));
    subplot(2,2,2)
    scatter(V_meas, y) %Log(I)-V plot
    xlabel('V_{meas}(V)')
    ylabel('log_{10}(|I_{meas}|)')
    
    %Resistance against bias voltage
    R = V_meas./I_meas;
    subplot(2,2,3)
    scatter(V_app, R)
    xlabel('V_{bias}(V)')
    ylabel('Resistance(\Omega)')
    
    %Extracting the current and voltage data to a txt file
    A=[V_app;V_meas;I_meas]; %Creates a 3D array of the voltage and current values
    A=A'; %Transposes array so that when it is converted to a table and text file it is the correct way round
    T=array2table(A, 'VariableNames',{'V_{bias}(V)','V_{meas}(V)', 'I_{meas}(A)'}); %Converts array to table with headers
    writetable(T, testname, 'Delimiter','\t') %Converts table to .txt file with tab delimiters
    
    %Closing communciation with both instruments
    fclose(keith236);
    fclose(dmm1705);
end



