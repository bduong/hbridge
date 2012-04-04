function CarGui()
%%  This function creates a GUI that allows the user to input commands
%   to control a RF controlled 1:24 scale car. Commands are inputted into
%   the GUI and then can be run all at once by hitting the RUN button.
%
%   Typing in the Detonate command automatically runs the Command List and
%   deactivates any further commands.
%
%   The commands are sent through a serial connect with an EZ430-RF2500.
%   The commands are sent from one EZ430-RF2500 to another EZ430-RF2500 through the
%   wireless interface. The commands are then translated to a corresponding
%   physical movement by the car.
%
%   List of Commands:
%
%   Moves Car Forward Specified Distance in FT
%       Forward <Distance>
%       F <Distance>
%
%   Moves Car Backward Specified Distance in FT
%       Back <Distance>
%       Backward <Distance>
%       B <Distance>
%
%   Turns Car to its Left
%       Turn Left
%       Left
%       L
%
%   Turns Car to its Right
%       Turn Right
%       Right
%       R
%
%   Simulates Detonation
%       Detonate
%
%   Delete Previous Commands
%       Delete

% -----------------------------------------------------------------
% |                                 --------------------------    |
% |   ------------------------      |                        |    |
% |   |    Command List    |S|      |        Car             |    |
% |   |                    |C|      |     Instruction        |    |
% |   |                    |R|      |     Simulation         |    |
% |   |                    |O|      |                        |    |
% |   |                    |L|      |                        |    |
% |   |                    |L|      |                        |    |
% |   ------------------------      --------------------------    |
% |                                                               |
% |                                       ------------            |
% |      -----------------                |    RUN   |            |
% |      | Command Enter |                |          |            |
% |      -----------------                ------------            |
% |                                                               |
% |                                                               |
% -----------------------------------------------------------------


%Instruction Encoding
%   -------------------------------
%  | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
%   -------------------------------
%
%   Bit  [7] - Start Bit
%   Bits [6-5] - Opcode
%   Bits [4-0] - Argument
%
%   Start Bit:
%       Bit 7 is the start bit to signal a new character
%       This should always be 0.
%
%   Opcode:
%       Bits 6 and 5 determine the Type of Command
%
%       00 - Detonate/Stop
%       01 - Forward
%       10 - Backward
%       11 - Turn
%
%   Forward/Backward:
%       Bits 4 through 0 determine Distance traveled with Forward/Backward
%           commands
%
%   Turn:
%       Bits 4 through 0 determine the direction the car turns
%
%       01100000 - Turn Left
%       01111111 - Turn Right
%
%   Detonate/Stop
%       Bits 4 through 0 determine the type of command
%
%
%       00011111 - Detonate


%By Ben Duong & Eugene Kolodenker ENG EC450 Spring 2011

%-------------------------------------------------------------------------
%% Main
% START OF MAIN FUNCTION (Initialization)

close all

%preallocate up to 50 instructions
movements = cell(1,50);
commands = cell(1,50);
waitpointer = zeros(1,50);
time = zeros(1,50);
cmdpointer = zeros(1,50);
handles = zeros(3,50);
position(50).car = zeros(1,4);
position(50).lights = cell(1,4);
position(50).tails = cell(1,4);
position(50).rev = cell(1,4);
position(50).tri = cell(1,2);
position(50).dir = 'u';
position(50).limits = zeros(1,4);

%initalize command counter variables
count = 1;
cmdcount = 1;


%initalize variables used for display
cmdstr = cell(1,1);
limits = [-3 3 -5 5];

%initalize command list to 20 commands
totalscroll = 20;
numofinstr = 0;

%Get the size of the screen in inches
set(0,'Units','Inches');
inch = get(0,'ScreenSize');
set(0,'Units','Pixels');

%Create the figure window with all units Normalized
mon = get(0,'ScreenSize');
o = figure('Name','Commando Car',...
    'Units','Normalized',...
    'Position',[0 0 .5 .5],...
    'Color',[135/255 135/255 135/255],...
    'visible','off','menubar','none');
movegui(o,'center');

%Create the uicontrols

%Command List (static text box)
cmdbox = uicontrol(...
    'Style','text',...
    'Units','Normalized',...
    'Position',[30/960 200/600 500/960 300/600],...
    'Background',[105/255 105/255 105/255],...
    'ForeGround','white',...
    'String',cmdstr,...
    'FontSize',12,...
    'HorizontalAlignment','Left');
%Command Enter (editable text box)
cmdedit = uicontrol(...
    'Style','edit',...
    'Units','Normalized',...
    'Position',[115/960 100/600 300/960 50/600],...
    'BackGround',[105/255 105/255 105/255],...
    'ForeGround','White',...
    'FontSize',11,...
    'CallBack',@cmdenter);
%Displayed if an invalid command is entered
valid = uicontrol(...
    'Style','text',...
    'Units','Normalized',...
    'Position',[115/960 150/600 300/960 25/600],...
    'BackGround',[135/255 135/255 135/255],...
    'String','Not a Valid Command',...
    'ForeGround','White',...
    'Visible','Off');
%RUN (push button)
run = uicontrol(...
    'Style','pushbutton',...
    'Units','Normalized',...
    'String','Run',...
    'FontName','Magneto',...
    'FontUnits','Normalized',...
    'FontSize',.5,...
    'Position', [650/960 50/600 200/960 100/600],...
    'CallBack',@cmdrun);
%SCROLL (slider bar)
scroll = uicontrol(...
    'Style','slider',...
    'Units','Normalized',...
    'Position',[510/960 200/600 20/960 300/600],...
    'Min',1,...
    'Max',20,...
    'SliderStep',[1/19 5/19],...
    'Value',20,...
    'CallBack',@scrollbar);
instrcount = uicontrol(...
    'Style','text',...
    'Units','Normalized',...
    'Position',[20/960 100/600 90/960 50/600],...
    'String',{'Instruction','Count','0'},...
    'Background',[135/255 135/255 135/255],...
    'ForeGround','white',...
    'FontWeight','bold',...
    'FontUnits','Normalized',...
    'FontSize',.25);

%Create an axis to hold the banner
banner = axes('Units','Normalized','Position',[10/960 510/600 550/960 130/960]);
cammandocar = imread('CarBanner.jpg');
image(cammandocar,'Parent',banner)
axis off

%Create an axis to hold the logo
logo = axes('Units','Normalized','position',[425/960 50/600 200/960 165/600]);
lambo = imread('lambologo.jpg');
image(lambo,'parent',logo)
axis off

%Create an axis for the Car Simulation
simulate = axes('Units','Normalized',...
    'position',[600/960 200/600 300/960 375/600],...
    'Color',[105/255 105/255 105/255],'YAxisLocation','Right');
axis(limits)
hold on

%Create the patches of the Head Lights
l1x = [-.25 -.5 0];
l2x = [.25 .5 0];
ly = [.5 1.5 1.5];
lightone = patch(l1x,ly,'w');
lighttwo = patch(l2x,ly,'w');
set([lightone lighttwo],'FaceColor',[238/255 221/255 130/255],...
    'EdgeColor',[238/255 221/255 130/255]);

%Create the Rectangle to symbolized the car
car = rectangle('position',[-.5 -1 1 2],'Curvature',[1 .5],...
    'FaceColor', [135/255 135/255 135/255]);


%Create the Patches for the Brake Tail Lights
t1x = [-.5 -.15 -.35 -.47];
t2x = [.5 .15 .35 .47];
ty = [-.5 -.99 -.9 -.72];
tailone = patch(t1x,ty,'r');
tailtwo = patch(t2x,ty,'r');

%Create the Patches for the Reverse Tail Lights
w1x = [-.15 -.35 -.25];
w2x = [.15 .35 .25];
wy = [-.99 -.9 -.85];
revone = patch(w1x,wy,'w');
revtwo = patch(w2x,wy,'w');

%Create the Patch for the center triangle
bx = [-.2 0 .2];
by = [0 .6 0];
tri = patch(bx,by,'k');



%initalize the car direction
cardir = 'u';


position(1).car = get(car,'Position');
position(1).lights = {l1x,ly,l2x,ly};
position(1).tails = {t1x,ty,t2x,ty};
position(1).rev = {w1x,wy,w2x,wy};
position(1).tri = {bx,by};
position(1).dir = cardir;
position(1).limits = limits;


%Credit text boxes
credits = uicontrol(...
    'Style','Text',...
    'Units','Normalized',...
    'Position',[0 5/600 300/960 50/600],...
    'BackGround',[135/255 135/255 135/255],...
    'ForeGround','white',...
    'String',sprintf('Benjamin Duong\nEugene Kolodenker\nBoston University 2011'),...
    'HorizontalAlignment','left');


%set the figure to visible
%Set it's resize function to recalibrate the scroll bar when the window is
%resized
set(o,'visible','on','ResizeFcn',@resize);

%focus the Command Enter Box
uicontrol(cmdedit)


%END OF MAIN FUNCTION

%-------------------------------------------------------------------------%
%% Resize
% CallBack Function for Resizing

    function resize(varargin)
        %Find how many commands can fit in one snapshot of the Command List
        %Box
        ppi = mon(4)/inch(4);
        cmdsize = get(cmdbox,'Position');
        figsize = get(o,'Position');
        cmdlength = mon(4)*figsize(4)*cmdsize(4);
        numofinstr = floor(cmdlength/(ppi*14/72));
        
        %update scrollbar
        scrollbar()
        
        %resize the credits box
        creditsize = get(credits,'Position');
        credlength = mon(4)*figsize(4)*creditsize(4);
        ipl = floor(credlength/3/ppi*72)-2;
        set(credits,'FontSize',ipl);
        set(cmdedit,'FontSize',ipl+2);
        
        
    end

%END OF RESIZING FUNCTION

%-------------------------------------------------------------------------
%% Scrollbar
% CallBack Function for the scrollbar
    function scrollbar(varargin)
        
        %Get the value from the slider and round it
        instrnum = round(totalscroll+1-get(scroll,'Value'));
        
        %build a new Command List from instrnum to instrnum+ <number of
        %instructions that can fit in one window>
        cmdstr = cell(1,numofinstr);
        if(instrnum+numofinstr < length(commands))
            for i = instrnum:instrnum+numofinstr
                cmdstr{i-instrnum+1} = commands{i};  %#ok<*AGROW>
            end
        else
            for i = instrnum:length(commands)
                cmdstr{i-instrnum+1} = commands{i};
            end
        end
        
        %display the new Command List
        set(cmdbox,'String',cmdstr)
    end

%END OF SCROLL BAR CALLBACK FUNCTION
%--------------------------------------------------------------------------
%% RUN
% Call Back For when The RUN button is pressed or when the DETONATE command
%is entered
%Send the command list to the EZ430-RF2500

    function cmdrun(varargin)
        
        set(valid,'Visible','Off')
        
        
        
        % serial sending here
        for i = 1:count-1
           % disp(movements{i})
            movements{i} = char(bin2dec(movements{i}));
        end
        
        
        
        
        
        %-----------------------------------------------------------------
        %   The Instructions are sent serially to an MSP430F2274 through
        %   the USCI UART at 9600 baud through the USB port
        %-----------------------------------------------------------------
        if(count-1 >= 50)
            count = 50;
        end
        
        %find the available serial ports
        ports = instrhwinfo('serial');
        avail = ports.SerialPorts;
        
        % if there is a valid external serial port
        if(length(avail) > 1)
            %create a waitbar object for the sending process
            set([run cmdedit],'Visible','off')
            wait = waitbar(0,'Sending Instruction Count');
            %create a serial object pointed at the second serial port
            rf2500 = serial(avail{end});
            %connect the serial object to the serial port
            fopen(rf2500);
            %send the number of instructions first
            fprintf(rf2500,sprintf('%c',char(count-1)));
          
            fscanf(rf2500);
            for i = 1:count-1
                %Send each instruction
                fprintf(rf2500,sprintf('%c',movements{i}));
                %disp(int32(movements{i}))
               %Update the waitbar
                waitbar(i/(count-1),wait,sprintf('Sending Instruction %s',commands{waitpointer(i)}));
                %Read for confirmation
                fscanf(rf2500);
                
            end
            
            %delete the sending waitbar
            delete(wait)
            
            %create a waitbar for the actual running
            running = waitbar(0,'RUNNING');
            
            %if the number of instructions is 10 clear the two bytes in the
            %input buffer
            if(count-1 == 10)
                fscanf(rf2500,'%c',2);
            end
            
            %wait until the byte signalling done is ready
            cc = 0;
            while((get(rf2500,'BytesAvailable') <= 0))
                %disp(rf2500.BytesAvailable);
                %fprintf('%d %d\n',cc,get(rf2500,'BytesAvailable'))
                waitbar(cc/(sum(time(1:count-1))),running);
                cc = cc +1;
            end
            
            %read it in
            %x=fscanf(rf2500,'%c',1);
            
            
            %disp(int32(x))
            %delete the running waitbar
            delete(running)
            
            
            %disconnect the serial object from the port
            fclose(rf2500);
            %delete the serial object
            delete(rf2500)
            %clear the variable
            clear rf2500
            
        end
        
        %------------------------------------------------------------------
        %   End of Transmission to through the USB port
        %------------------------------------------------------------------
        %
        
        
        %If this was called from hitting the RUN Push Button
        
        if(varargin{1} == run)
            set([run cmdedit],'Visible','On')
            %delete lines and distance markers
            for i = 1:cmdcount
                set(handles(:,i),'visible','off')
            end
            
            %Clear the Command List and Reset the command counters
            cmdstr = '';
            count = 1;
            cmdcount = 1;
            commands(:) = [];
            set(cmdbox,'String',cmdstr)
            
            %rescale axis to the car
            carpos = get(car,'Position');
            switch cardir
                case {'u','d'}
                    limits = [carpos(1)+.5-3 carpos(1)+.5+3 carpos(2)+1-5 carpos(2)+1+5];
                case {'l','r'}
                    limits = [carpos(1)+1-3 carpos(1)+1+3 carpos(2)+.5-5 carpos(2)+.5+5];
                    
            end
            axis(simulate,limits)
            
            
            
            position(cmdcount).car = carpos;
            position(cmdcount).lights = {get(lightone,'XData'),get(lightone,'YData'),get(lighttwo,'XData'),get(lighttwo,'YData')};
            position(cmdcount).tails = {get(tailone,'XData'),get(tailone,'YData'),get(tailtwo,'XData'),get(tailtwo,'YData')};
            position(cmdcount).rev = {get(revone,'XData'),get(revone,'YData'),get(revtwo,'XData'),get(revtwo,'YData')};
            position(cmdcount).tri = {get(tri,'XData'),get(tri,'yData')};
            position(cmdcount).dir = cardir;
            position(cmdcount).limits = limits;
            
            set(instrcount,'String',{'Instruction','Count','0'})
            
            %give control back to the editable text box
        uicontrol(cmdedit)
        
        end
        
        
    end

%END OF COMMAND RUN CALLBACK FUNCTION

%--------------------------------------------------------------------------
%% Enter Command
%Call Back Function for when a Command is entered
    function cmdenter(varargin)
        delete = 0;
        %Get the Command as a string
        command = strtrim(get(cmdedit,'String'));
        
        %Clear the edit text box
        set(cmdedit,'String','');
        set(valid,'Visible','Off')
        
        %Check the command against acceptable commands
        if( strcmpi(command,'turn left') || strcmpi(command,'l') || strcmpi(command,'left'))
            %Check for a left turn command
            movements{count} = '01100000';
            %"pointer" for waitbar
            waitpointer(count) = cmdcount;
            time(count) = 50;
            cmdpointer(cmdcount) = count;
            count = count + 1;
            modplot('l');
            
            
        elseif( strcmpi(command,'turn right') || strcmpi(command,'r') || strcmpi(command,'right'))
            %Check f  or a Right turn command
            movements{count} = '01111111';
            waitpointer(count) = cmdcount;
            time(count) = 50;
            cmdpointer(cmdcount) = count;
            count = count + 1;
            modplot('r');
            
            
        elseif( strcmpi(command,'detonate'))
            %Check for a detonation command
            movements{count} = '00011111';
            %"pointer" for waitbar
            waitpointer(count) = cmdcount;
            time(count) = 25;
            cmdpointer(cmdcount) = count;
            count = count + 1;
            
            modplot('b');
            %disable anymore commands
            set([cmdedit run],'Visible','Off')
            %turn off the lights to the car
            set([lightone lighttwo],'XData',[],'YData',[])
            
            commands{cmdcount} = [sprintf('\n%d. ', cmdcount)  upper(command)];
                %If this was called from calling the "DETONATE" command
            
            %Set the car to color red
            set([tri revone revtwo],'FaceColor','red')
            
            %Make explosion lines
            carpos = get(car,'Position');
            switch cardir
                case {'u','d'}
                    line([carpos(1)+.5 carpos(1)+.5],[carpos(2)+2.25 carpos(2)+3],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+1.125 carpos(1)+1.628],[carpos(2)+2 carpos(2)+2.53],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+1.25 carpos(1)+2],[carpos(2)+1 carpos(2)+1],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+1.125 carpos(1)+1.628],[carpos(2) carpos(2)-.53],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+.5 carpos(1)+.5],[carpos(2)-.25 carpos(2)-1],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)-.125 carpos(1)-.628],[carpos(2)+2 carpos(2)+2.53],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)-.25 carpos(1)-1],[carpos(2)+1 carpos(2)+1],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)-.125 carpos(1)-.628],[carpos(2) carpos(2)-.53],'Color',[1 165/255 0],'LineWidth',2)
                case{'l','r'}
                    line([carpos(1)+2.25 carpos(1)+3],[carpos(2)+.5 carpos(2)+.5],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+2 carpos(1)+2.53],[carpos(2)+1.125 carpos(2)+1.628],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+1 carpos(1)+1],[carpos(2)+1.25 carpos(2)+2],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1) carpos(1)-.53],[carpos(2)+1.125 carpos(2)+1.628],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)-.25 carpos(1)-1],[carpos(2)+.5 carpos(2)+.5],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+2 carpos(1)+2.53],[carpos(2)-.125 carpos(2)-.628],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1)+1 carpos(1)+1],[carpos(2)-.25 carpos(2)-1],'Color',[1 165/255 0],'LineWidth',2)
                    line([carpos(1) carpos(1)-.53],[carpos(2)-.125 carpos(2)-.628],'Color',[1 165/255 0],'LineWidth',2)
            end
           
            %automatically run the command list
            cmdrun(-10);
        elseif(strcmpi(command,'delete'))
            if(cmdcount > 1)
                instrnum = round(totalscroll+1-get(scroll,'Value'));
                if(instrnum + numofinstr >= length(cmdcount) || numofinstr >=length(cmdcount))
                    last = find(~cellfun('isempty',cmdstr),1,'last');
                    cmdstr(last) =[];
                    set(cmdbox,'String',cmdstr)
                end
                
                commands(find(~cellfun('isempty',commands),1,'last')) = [];
                
                set(handles(:,cmdcount-1),'Visible','Off')
                
                
                cmdcount = cmdcount - 1;
                count = cmdpointer(cmdcount);
                limits = position(cmdcount).limits;
                cardir = position(cmdcount).dir;
                axis(simulate,limits)
                set(car,'Position',position(cmdcount).car)
                set(lightone,'XData',position(cmdcount).lights{1},'YData',position(cmdcount).lights{2})
                set(lighttwo,'XData',position(cmdcount).lights{3},'YData',position(cmdcount).lights{4})
                set(tailone,'XData',position(cmdcount).tails{1},'YData',position(cmdcount).tails{2})
                set(tailtwo,'XData',position(cmdcount).tails{3},'YData',position(cmdcount).tails{4})
                set(revone,'XData',position(cmdcount).rev{1},'YData',position(cmdcount).rev{2})
                set(revtwo,'XData',position(cmdcount).rev{3},'YData',position(cmdcount).rev{4})
                set(tri,'XData',position(cmdcount).tri{1},'YData',position(cmdcount).tri{2})
                set(instrcount,'String',{'Instruction','Count',num2str(count-1)})
                
                if(count <= 50)
                    set(instrcount,'ForeGroundColor','white')
                end
                
            end
            delete = 1;
        else
            %Otherwise it must be a forward or backward command
            
            %initalize the instruction to "STOP"
            instruction = '00000000';
            
            %seperate the direction and distance
            [direction distance]= strtok(command);
            
            
            
            %Check the Direction of movement
            
            if((strcmpi(direction,'forward') || strcmpi(direction,'f')) && ~isempty(distance))
                %Distance is accurate to .1 of a foot
                distance = round(str2double(distance)*10);
                
                %update simulation
                modplot('u',distance/10);
                
                %set opcode for forward
                instruction(3) = '1';
                
                
                cmdpointer(cmdcount) = count;
                %if the distance is over 6.3 feet it must be broken up
                %into sections of less than 6.3 feet
                while(distance >= 32)
                    movements{count} = binconvert(distance,instruction);
                    %"pointer" for waitbar
                    waitpointer(count) = cmdcount;
                    time(count) = 3.1*250;
                    count = count + 1;
                    distance = distance - 31;
                    
                end
                
                %encode the distance into the instruction
                movements{count} = binconvert(distance,instruction);
                %"pointer" for waitbar
                waitpointer(count) = cmdcount;
                time(count) = distance/10*250;
                
                %add one to the command counter
                count = count +1;
                
            elseif ((strcmpi(direction,'backward') || strcmpi(direction,'back') ...
                    || strcmpi(direction,'b')) && ~isempty(distance))
                %Backward Movement
                
                %Distance is accurate to .1 of a foot
                distance = round(str2double(distance)*10);
                
                %update simulation
                modplot('d',distance/10);
                
                %set opcode for backward
                instruction(2) = '1';
                
                
                cmdpointer(cmdcount) = count;
                %if the distance is over 6.3 feet it must be broken up
                %into sections of less than 6.3 feet
                while(distance >= 32)
                    movements{count} = binconvert(distance,instruction);
                    %"pointer" for waitbar
                    waitpointer(count) = cmdcount;
                    time(count) = 3.1*250;
                    count = count + 1;
                    distance = distance - 31;
                   
                end
                
                %encode the distance into the instruction
                movements{count} = binconvert(distance,instruction);
                %"pointer" for waitbar
                waitpointer(count) = cmdcount;
                time(count) = distance/10*250;
                %add one to the instruction counter
                count = count +1;
                
            else
                
                %if the instruction is not a valid one display INVALID
                %message
                set(valid,'Visible','On');
                
            end
        end
        
        
        %If the command was valid then display it in the command list
        if(strcmpi(get(valid,'Visible'),'off') && ~delete)
            
            instrnum = round(totalscroll+1-get(scroll,'Value'));
            
            %add the latest command to the Command List
            cmdstr{cmdcount+1-instrnum} = [sprintf('%d. ', cmdcount)  upper(command)];
            commands{cmdcount} = [sprintf('%d. ', cmdcount)  upper(command)];
            
            %update the Command List
            set(cmdbox,'String',cmdstr)
            set(instrcount,'String',{'Instruction','Count',num2str(count-1)})
            
            if(count >50)
                set(instrcount,'ForeGroundColor',[.7 0 0])
            end
            
            %If the Command List Fills the box
            if(cmdcount > totalscroll)
                totalscroll = cmdcount;
                
                %update the max of the scrollbar and the step size
                %but keep it on the same command number
                set(scroll,'Max',cmdcount,'SliderStep',[1/(cmdcount-1) 5/(cmdcount-1)],'Value',get(scroll,'Value')+1);
            end
            
            %If the Last Command in the Command List is also the latest
            %command advance the Command List when a new command is entered
            if(round(totalscroll+1-get(scroll,'Value'))+numofinstr == cmdcount)
                set(scroll,'Value',get(scroll,'Value')-1)
                
                %update scroll bar
                scrollbar();
            end
            
            %add one to the command counter
            cmdcount = cmdcount + 1;
            
        end
    end

%END OF COMMAND ENTER CALLBACK FUNCTION

%--------------------------------------------------------------------------
%% Instruction Encode
%Subfunction to do binary encoding of the instruction

    function instrout = binconvert(distance, instruction)
        
        %If the distance is still over 12.7 feet set this instruction to
        %12.7 feet
        if(distance >= 32)
            instruction(4:8) = '11111';
        else
            %otherwise convert the distance to binary
            distance = dec2bin(distance);
            
            %replace the bits in the input instruction with the distance
            for i = 1:length(distance)
                instruction(9-i) = distance(end+1-i);
            end
            
        end
        
        %output the encoded instruction
        instrout = instruction;
        
    end

%END OF BINARY ENCODING SUBFUNCTION

%--------------------------------------------------------------------------
%% Mod Plot
%Function to update simulation

    function modplot(direction,varargin)
        
        %get the position of the car now
        carpos = get(car,'Position');
        %save the position of the car for path tracking
        oldpos = carpos;
        
        %Check the direction the car is going (forward,backward,left turn,
        %right turn)
        
        %Outer Switch: <direction>
        %   'u' - Car is moving forward
        %   'd' - Car is moving backward
        %   'r' - Car is turning right
        %   'l' - Car is turning left
        %   'b' - Detonate Car
        %
        %Inner Switch: <cardir>
        %   'u' - Car is Facing North
        %   'd' - Car is Facing South
        %   'l' - Car is Facing West
        %   'r' - Car is Facing East
        
        switch direction
            case 'u'
                switch cardir
                    case 'u'
                        %add the distance to the y position
                        carpos(2) = carpos(2) + varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [carpos(1)+.5 carpos(1)+.5];
                        y = [oldpos(2)+1 carpos(2)+1];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+.5, oldpos(2)+1,'co','MarkerSize',7);
                        
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(carpos(1)+.6,mean(y),sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+1.5 carpos(2)+2.5 carpos(2)+2.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1-.5 carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1.6 carpos(2)+1];
                        
                    case 'd'
                        
                        %add the distance to the y position
                        carpos(2) = carpos(2)-varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [carpos(1)+.5 carpos(1)+.5];
                        y = [oldpos(2)+1 carpos(2)+1];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+.5, oldpos(2)+1,'co','MarkerSize',7);
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(carpos(1)-.3,mean(y),sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+.5 carpos(2)-.5 carpos(2)-.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1.5 carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1-.6 carpos(2)+1];
                        
                    case 'r'
                        %add the distance to the x position
                        carpos(1) = carpos(1) + varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [oldpos(1)+1 carpos(1)+1];
                        y = [oldpos(2)+.5 oldpos(2)+.5];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+1, oldpos(2)+.5,'co','MarkerSize',7);
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(mean(x),carpos(2) + .8,sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+1.5 carpos(1)+2.5 carpos(1)+2.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2) carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.47];
                        t2y = [carpos(2)+1 carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.47];
                        t1x = [carpos(1)+1-.5 carpos(1)+1-.99 carpos(1)+1-.9 carpos(1)+1-.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.25];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.25];
                        w1x = [carpos(1)+1-.99 carpos(1)+1-.9 carpos(1)+1-.85];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                        
                    case 'l'
                        %add the distance to the x position
                        carpos(1) = carpos(1) - varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [oldpos(1)+1 carpos(1)+1];
                        y = [oldpos(2)+.5 oldpos(2)+.5];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+1, oldpos(2)+.5,'co','MarkerSize',7);
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(mean(x),carpos(2) + .3,sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.5 carpos(1)-.5 carpos(1)-.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2) carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.47];
                        t2y = [carpos(2)+1 carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.47];
                        t1x = [carpos(1)+1.5 carpos(1)+1.99 carpos(1)+1.9 carpos(1)+1.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.25];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.25];
                        w1x = [carpos(1)+1.99 carpos(1)+1.9 carpos(1)+1.85];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1-.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                        
                end
                
                %update all patches
                set(lightone,'XData',l1x,'YData',l1y)
                set(lighttwo,'XData',l2x,'YData',l2y)
                set(tailone,'XData',t1x,'YData',t1y)
                set(tailtwo,'XData',t2x,'YData',t2y)
                set(revone,'XData',w1x,'YData',w1y)
                set(revtwo,'XData',w2x,'YData',w2y)
                set(tri,'XData',bx,'YData',by)
                
                %Set new axis limits if needed
                limits = newlimits(carpos,limits);
                axis(simulate, limits);
                
                
                %update the car's position
                position(cmdcount+1).car = carpos;
                position(cmdcount+1).lights = {l1x,l1y,l2x,l2y};
                position(cmdcount+1).tails = {t1x,t1y,t2x,t2y};
                position(cmdcount+1).rev = {w1x,w1y,w2x,w2y};
                position(cmdcount+1).tri = {bx,by};
                position(cmdcount+1).dir = cardir;
                position(cmdcount+1).limits = limits;
                set(car,'Position',carpos)
            case 'd'
                switch cardir
                    case 'u'
                        carpos(2) = carpos(2) - varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [carpos(1)+.5 carpos(1)+.5];
                        y = [oldpos(2)+1 carpos(2)+1];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+.5, oldpos(2)+1,'co','MarkerSize',7);
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(carpos(1)+.6,mean(y),sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+1.5 carpos(2)+2.5 carpos(2)+2.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1-.5 carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1.6 carpos(2)+1];
                        
                    case 'd'
                        carpos(2) = carpos(2) + varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [carpos(1)+.5 carpos(1)+.5];
                        y = [oldpos(2)+1 carpos(2)+1];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+.5, oldpos(2)+1,'co','MarkerSize',7);
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(carpos(1)-.3,mean(y),sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+.5 carpos(2)-.5 carpos(2)-.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1.5 carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1-.6 carpos(2)+1];
                        
                    case 'r'
                        carpos(1) = carpos(1) - varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [oldpos(1)+1 carpos(1)+1];
                        y = [oldpos(2)+.5 oldpos(2)+.5];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+1, oldpos(2)+.5,'co','MarkerSize',7);
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(mean(x),carpos(2) + .8,sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+1.5 carpos(1)+2.5 carpos(1)+2.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2) carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.47];
                        t2y = [carpos(2)+1 carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.47];
                        t1x = [carpos(1)+1-.5 carpos(1)+1-.99 carpos(1)+1-.9 carpos(1)+1-.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.25];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.25];
                        w1x = [carpos(1)+1-.99 carpos(1)+1-.9 carpos(1)+1-.85];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                        
                    case 'l'
                        carpos(1) = carpos(1) + varargin{1};
                        
                        %plot the path taken in yellow with a marker
                        %at the starting point
                        x = [oldpos(1)+1 carpos(1)+1];
                        y = [oldpos(2)+.5 oldpos(2)+.5];
                        handles(1:2,cmdcount) = plot(simulate,x,y,'y', oldpos(1)+1, oldpos(2)+.5,'co','MarkerSize',7);
                        
                        %create a text object to display the distance
                        %travelled
                        handles(3,cmdcount) = text(mean(x),carpos(2) + .3,sprintf('%.1f ft',varargin{1}),'Color','white');
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.5 carpos(1)-.5 carpos(1)-.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2) carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.47];
                        t2y = [carpos(2)+1 carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.47];
                        t1x = [carpos(1)+1.5 carpos(1)+1.99 carpos(1)+1.9 carpos(1)+1.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.25];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.25];
                        w1x = [carpos(1)+1.99 carpos(1)+1.9 carpos(1)+1.85];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1-.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                        
                end
                
                
                %update all patches
                set(lightone,'XData',l1x,'YData',l1y)
                set(lighttwo,'XData',l2x,'YData',l2y)
                set(tailone,'XData',t1x,'YData',t1y)
                set(tailtwo,'XData',t2x,'YData',t2y)
                set(revone,'XData',w1x,'YData',w1y)
                set(revtwo,'XData',w2x,'YData',w2y)
                set(tri,'XData',bx,'YData',by)
                
                %Set new axis limits if needed
                limits = newlimits(carpos,limits);
                axis(simulate, limits);
                
                %update the car's position
                position(cmdcount+1).car = carpos;
                position(cmdcount+1).lights = {l1x,l1y,l2x,l2y};
                position(cmdcount+1).tails = {t1x,t1y,t2x,t2y};
                position(cmdcount+1).rev = {w1x,w1y,w2x,w2y};
                position(cmdcount+1).tri = {bx,by};
                position(cmdcount+1).dir = cardir;
                position(cmdcount+1).limits = limits;
                set(car,'Position',carpos)
                
            case 'l'
                switch cardir
                    case 'u'
                        
                        %update the car's position
                        carpos(1) = carpos(1) - .5;
                        carpos(2) = carpos(2) +.5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'l';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.5 carpos(1)-.5 carpos(1)-.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2)+.02 carpos(2)+.5-.15 carpos(2)+.5-.3 carpos(2)+.5-.45];
                        t2y = [carpos(2)+.98 carpos(2)+.5+.15 carpos(2)+.5+.3 carpos(2)+.5+.45];
                        t1x = [carpos(1)+1.58 carpos(1)+2 carpos(1)+1.99 carpos(1)+1.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.3 ];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.3 ];
                        w1x = [carpos(1)+1.99 carpos(1)+1.9 carpos(1)+1.99 ];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1-.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                    case 'd'
                        
                        %update the car's position
                        carpos(1) = carpos(1) -.5;
                        carpos(2) = carpos(2) + .5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'r';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+1.5 carpos(1)+2.5 carpos(1)+2.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2)+.02 carpos(2)+.5-.15 carpos(2)+.5-.3 carpos(2)+.5-.45];
                        t2y = [carpos(2)+.98 carpos(2)+.5+.15 carpos(2)+.5+.3 carpos(2)+.5+.45];
                        t1x = [carpos(1)+1-.58 carpos(1)+1-1 carpos(1)+1-.99 carpos(1)+1-.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.3];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.3];
                        w1x = [carpos(1)+1-.99 carpos(1)+1-.9 carpos(1)+1-.99];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                        
                        
                    case 'l'
                        
                        %update the car's position
                        carpos(1) = carpos(1) +.5;
                        carpos(2) = carpos(2) -.5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'd';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+.5 carpos(2)-.5 carpos(2)-.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1.5 carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1-.6 carpos(2)+1];
                        
                    case 'r'
                        
                        %update the car's position
                        carpos(1) = carpos(1) +.5;
                        carpos(2) = carpos(2) -.5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'u';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+1.5 carpos(2)+2.5 carpos(2)+2.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1-.5 carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1.6 carpos(2)+1];
                        
                end
                %update all patches
                set(lightone,'XData',l1x,'YData',l1y)
                set(lighttwo,'XData',l2x,'YData',l2y)
                set(tailone,'XData',t1x,'YData',t1y)
                set(tailtwo,'XData',t2x,'YData',t2y)
                set(revone,'XData',w1x,'YData',w1y)
                set(revtwo,'XData',w2x,'YData',w2y)
                set(tri,'XData',bx,'YData',by)
                
                %Set new axis limits if needed
                limits = newlimits(carpos,limits);
                axis(simulate, limits);
                
                %update the car's position
                position(cmdcount+1).car = carpos;
                position(cmdcount+1).lights = {l1x,l1y,l2x,l2y};
                position(cmdcount+1).tails = {t1x,t1y,t2x,t2y};
                position(cmdcount+1).rev = {w1x,w1y,w2x,w2y};
                position(cmdcount+1).tri = {bx,by};
                position(cmdcount+1).dir = cardir;
                position(cmdcount+1).limits = limits;
                set(car,'Position',carpos)
                
            case 'r'
                switch cardir
                    case 'u'
                        
                        %update the car's position
                        carpos(1) = carpos(1) - .5;
                        carpos(2) = carpos(2) +.5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'r';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+1.5 carpos(1)+2.5 carpos(1)+2.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2)+.02 carpos(2)+.5-.15 carpos(2)+.5-.3 carpos(2)+.5-.45];
                        t2y = [carpos(2)+.98 carpos(2)+.5+.15 carpos(2)+.5+.3 carpos(2)+.5+.45];
                        t1x = [carpos(1)+1-.58 carpos(1)+1-1 carpos(1)+1-.99 carpos(1)+1-.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.3];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.3];
                        w1x = [carpos(1)+1-.99 carpos(1)+1-.9 carpos(1)+1-.99];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                        
                    case 'd'
                        
                        %update the car's position
                        carpos(1) = carpos(1) -.5;
                        carpos(2) = carpos(2) +.5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'l';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.5 carpos(1)-.5 carpos(1)-.5];
                        l1y = [carpos(2)+.25 carpos(2) carpos(2)+.5];
                        l2x=l1x;
                        l2y = [carpos(2)+.75 carpos(2)+.5 carpos(2)+1];
                        
                        %update the braking light patch positions
                        t1y = [carpos(2)+.02 carpos(2)+.5-.15 carpos(2)+.5-.3 carpos(2)+.5-.45];
                        t2y = [carpos(2)+.98 carpos(2)+.5+.15 carpos(2)+.5+.3 carpos(2)+.5+.45];
                        t1x = [carpos(1)+1.58 carpos(1)+2 carpos(1)+1.99 carpos(1)+1.72];
                        t2x = t1x;
                        
                        %update the reverse light patch positions
                        w1y = [carpos(2)+.5-.15 carpos(2)+.5-.35 carpos(2)+.5-.3 ];
                        w2y = [carpos(2)+.5+.15 carpos(2)+.5+.35 carpos(2)+.5+.3 ];
                        w1x = [carpos(1)+1.99 carpos(1)+1.9 carpos(1)+1.99 ];
                        w2x = w1x;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+1 carpos(1)+1-.6 carpos(1)+1];
                        by = [carpos(2)+.5-.2 carpos(2)+.5 carpos(2)+.5+.2];
                        
                    case 'l'
                        
                        %update the car's position
                        carpos(1) = carpos(1) +.5;
                        carpos(2) = carpos(2) - .5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'u';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+1.5 carpos(2)+2.5 carpos(2)+2.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1-.5 carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1-.99 carpos(2)+1-.9 carpos(2)+1-.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1.6 carpos(2)+1];
                        
                    case 'r'
                        
                        %update the car's position
                        carpos(1) = carpos(1) +.5;
                        carpos(2) = carpos(2) -.5;
                        temp = carpos(3);
                        carpos(3) = carpos(4);
                        carpos(4) = temp;
                        
                        %update the direction the car is facing
                        cardir = 'd';
                        
                        %update the head light patch positions
                        l1x = [carpos(1)+.25 carpos(1) carpos(1)+.5];
                        l1y = [carpos(2)+.5 carpos(2)-.5 carpos(2)-.5];
                        l2x= [carpos(1)+.75 carpos(1)+.5 carpos(1)+1];
                        l2y = l1y;
                        
                        %update the braking light patch positions
                        t1x = [carpos(1) carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.47];
                        t2x = [carpos(1)+1 carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.47];
                        t1y = [carpos(2)+1.5 carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.72];
                        t2y = t1y;
                        
                        %update the reverse light patch positions
                        w1x = [carpos(1)+.5-.15 carpos(1)+.5-.35 carpos(1)+.5-.25];
                        w2x = [carpos(1)+.5+.15 carpos(1)+.5+.35 carpos(1)+.5+.25];
                        w1y = [carpos(2)+1.99 carpos(2)+1.9 carpos(2)+1.85];
                        w2y = w1y;
                        
                        %update the center triangle patch positions
                        bx = [carpos(1)+.5-.2 carpos(1)+.5 carpos(1)+.5+.2];
                        by = [carpos(2)+1 carpos(2)+1-.6 carpos(2)+1];
                        
                end
                %update all patches
                set(lightone,'XData',l1x,'YData',l1y)
                set(lighttwo,'XData',l2x,'YData',l2y)
                set(tailone,'XData',t1x,'YData',t1y)
                set(tailtwo,'XData',t2x,'YData',t2y)
                set(revone,'XData',w1x,'YData',w1y)
                set(revtwo,'XData',w2x,'YData',w2y)
                set(tri,'XData',bx,'YData',by)
                
                %Set new axis limits if needed
                limits = newlimits(carpos,limits);
                axis(simulate, limits);
                
                %update the car's position
                position(cmdcount+1).car = carpos;
                position(cmdcount+1).lights = {l1x,l1y,l2x,l2y};
                position(cmdcount+1).tails = {t1x,t1y,t2x,t2y};
                position(cmdcount+1).rev = {w1x,w1y,w2x,w2y};
                position(cmdcount+1).tri = {bx,by};
                position(cmdcount+1).dir = cardir;
                position(cmdcount+1).limits = limits;
                set(car,'Position',carpos)
            case 'b'
                
                %if the car is detonated set the color to red
                set(car,'FaceColor','Red')
                
        end
    end

%END OF SIMULATION UPDATE FUNCTION

%--------------------------------------------------------------------------
%% Limits Check
%Function to check if the limits need to be updated

    function nlimits = newlimits(carpos,limits)
        %ratio of X range to Y Range is 7:11
        
        oldlimits = limits;
        
        %If the car moves out of the X Range
        
        if(carpos(1)+2 > limits(2))
            %car moves east
            
            %change the x max
            limits(2) = carpos(1)+3;
            
            %Distance added to X Range scaled to y range
            dist = (carpos(1)+3 -oldlimits(2))*11/14;
            
            %change y range
            limits(3) = limits(3) -dist;
            limits(4) = limits(4) + dist;
            
        elseif(carpos(1) < limits(1))
            %car moves west
            
            %change the x min
            limits(1) = carpos(1)-3;
            
            %Distance added to X Range scaled to y range
            dist = (oldlimits(1)-carpos(1) + 3)*11/14;
            
            %change y range
            limits(3) = limits(3) -dist;
            limits(4) = limits(4) + dist;
        end
        
        
        %If the car moves out of the Y range
        
        if(carpos(2)+2 > limits(4))
            %car moves North
            
            %change the y max
            limits(4) = carpos(2)+3;
            
            %Distance added to Y Range scaled to the x range
            dist = (carpos(2)+3 -oldlimits(4))*7/22;
            
            %change the x range
            limits(1) = limits(1) - dist;
            limits(2) = limits(2) + dist;
            
            
        elseif(carpos(2) < limits(3))
            %car moves South
            
            %change the y min
            limits(3) = carpos(2)-3;
            
            %Distance added to Y Range scaled to the x range
            dist = (oldlimits(3)-carpos(2)+3)*7/22;
            
            %change the x range
            limits(1) = limits(1) - dist;
            limits(2) = limits(2) + dist;
        end
        
        %output the new limits
        nlimits = limits;
        
        
        
    end

end

%END OF LIMIT UPDATE FUNCTION

%-------------------------------------------------------------------------
