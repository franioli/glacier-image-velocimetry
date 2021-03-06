function [xp,yp,up,vp,SnR,Pkh]=GIVtrackmultifinal(A,B,winsize,overlap,initialdx,initialdy)
% function [x,y,u,v,SnR,PeakHeight]=finalpass(A,B,winsize,overlap,initialdx,initialdy)
%
% Provides the final pass to get the displacements with
% subpixel resolution.
%
%


%This function is based upon a multipass solver written by Kristian Sveen
%as part of the matPIV toolbox. It has been adapted for use as part of GIV.
%It is distributed under the terms of the Gnu General Public License
%manager.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                   %% GLACIER IMAGE VELOCIMETRY (GIV) %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Code written by Max Van Wyk de Vries @ University of Minnesota
%Credit to Ben Popken and Andrew Wickert for portions of the toolbox.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Portions of this toolbox are based on a number of codes written by
%previous authors, including matPIV, IMGRAFT, PIVLAB, M_Map and more.
%Credit and thanks are due to the authors of these toolboxes, and for
%sharing their codes online. See the user manual for a full list of third 
%party codes used here. Accordingly, you are free to share, edit and
%add to this GIV code. Please give us credit if you do, and share your code 
%with the same conditions as this.

% Read the associated paper here: 
% https://doi.org/10.5194/tc-2020-204
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %Version 0.7, Autumn 2020%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                  %Feel free to contact me at vanwy048@umn.edu%

if length(winsize)==1
    M=winsize;
else
    M=winsize(1); winsize=winsize(2);
end
cj=1;
[sy,sx]=size(A);

% Allocate space for matrixes
xp=zeros(ceil((size(A,1)-winsize)/((1-overlap)*winsize))+1, ...
    ceil((size(A,2)-M)/((1-overlap)*M))+1);
yp=xp; up=xp; vp=xp; SnR=xp; Pkh=xp;

IN=zeros(size(A)); 

%%%%%%%%%%%%%%% MAIN LOOP %%%%%%%%%%%%%%%%%%%%%%%%%
tic
for jj=1:((1-overlap)*winsize):sy-winsize+1
    ci=1;
    for ii=1:((1-overlap)*M):sx-M+1
        if IN(jj+winsize/2,ii+M/2)~=1
            if isnan(initialdx(cj,ci))
                initialdx(cj,ci)=0;
            end
            if isnan(initialdy(cj,ci))
                initialdy(cj,ci)=0;
            end
            if jj+initialdy(cj,ci)<1
                initialdy(cj,ci)=1-jj;
            elseif jj+initialdy(cj,ci)>sy-winsize+1
                initialdy(cj,ci)=sy-winsize+1-jj;
            end
            if ii+initialdx(cj,ci)<1
                initialdx(cj,ci)=1-ii;
            elseif ii+initialdx(cj,ci)>sx-M+1
                initialdx(cj,ci)=sx-M+1-ii;
            end
            D2=B(jj+initialdy(cj,ci):jj+winsize-1+initialdy(cj,ci),ii+initialdx(cj,ci):ii+M-1+initialdx(cj,ci));
            E=A(jj:jj+winsize-1,ii:ii+M-1);
            stad1=std(E(:));
            stad2=std(D2(:));
            if stad1==0, stad1=1; end
            if stad2==0, stad2=1; end
            E=E-mean(E(:));
            F=D2-mean(D2(:));
            %E(E<0)=0; F(F<0)=0;
            
            %%%%%%%%%%%%%%%%%%%%%% Calculate the normalized correlation:
            R=xcorrelate(E,F)./(winsize*M*stad1*stad2);
            %%%%%%%%%%%%%%%%%%%%%% Find the position of the maximal value of R
            %%%%%%%%%%%%%%%%%%%%%% _IF_ the standard deviation is NOT NaN.
            if all(~isnan(R(:))) && ~all(R(:)==0)  %~isnan(stad1) & ~isnan(stad2)
                if size(R,1)==(winsize-1)
                    [max_y1,max_x1]=find(R==max(R(:)));
                    
                else
                    [max_y1,max_x1]=find(R==max(max(R(0.5*winsize+2:1.5*winsize-3,...
                        0.5*M+2:1.5*M-3))));
                end
                if length(max_x1)>1
                    max_x1=round(sum(max_x1.^2)./sum(max_x1));
                    max_y1=round(sum(max_y1.^2)./sum(max_y1));
                end
                if max_x1==1, max_x1=2; end
                if max_y1==1, max_y1=2; end
                
                
                %Sub-pixel estimator:
                % 3-point peak fit using centroid, gaussian (default)
                % or parabolic fit
                [x0, y0]=GIVtrackmultipeak(max_x1,max_y1,R(max_y1,max_x1),...
                    R(max_y1,max_x1-1),R(max_y1,max_x1+1),...
                    R(max_y1-1,max_x1),R(max_y1+1,max_x1),2,[M,winsize]);
                
                % Find the signal to Noise ratio
                R2=R;
                try
                    %consider changing this from try-catch to a simpler
                    %distance check. The key here is the distance tot he
                    %image edge. When peak is close to edge, this NaN
                    %allocation may fail.
                    R2(max_y1-3:max_y1+3,max_x1-3:max_x1+3)=NaN;
                catch
                    R2(max_y1-1:max_y1+1,max_x1-1:max_x1+1)=NaN;
                end
                if size(R,1)==(winsize-1)
                    [p2_y2,p2_x2]=find(R2==max(R2(:)));                    
                else
                    [p2_y2,p2_x2]=find(R2==max(max(R2(0.5*winsize:1.5*winsize-1,0.5*M:1.5*M-1))));
                end
                if length(p2_x2)>1
                    p2_x2=p2_x2(round(length(p2_x2)/2));
                    p2_y2=p2_y2(round(length(p2_y2)/2));
                elseif isempty(p2_x2)
                    
                end
                % signal to noise:
                snr=R(max_y1,max_x1)/R2(p2_y2,p2_x2);

                
                %%%%%%%%%%%%%%%%%%%%%% Store the displacements, SnR and Peak Height.
                up(cj,ci)=(-x0+initialdx(cj,ci));
                vp(cj,ci)=(-y0+initialdy(cj,ci));
                xp(cj,ci)=(ii+(M/2)-1);
                yp(cj,ci)=(jj+(winsize/2)-1);
                SnR(cj,ci)=snr;
                Pkh(cj,ci)=R(max_y1,max_x1);
            else
                up(cj,ci)=NaN; vp(cj,ci)=NaN; SnR(cj,ci)=NaN; Pkh(cj,ci)=0;
                xp(cj,ci)=(ii+(M/2)-1);
                yp(cj,ci)=(jj+(winsize/2)-1);
            end
            ci=ci+1;
        else
            xp(cj,ci)=(M/2)+ii-1;
            yp(cj,ci)=(winsize/2)+jj-1;
            up(cj,ci)=NaN; vp(cj,ci)=NaN;
            SnR(cj,ci)=NaN; Pkh(cj,ci)=NaN;ci=ci+1;
        end
    end
    cj=cj+1;
end


% now we inline the function xcorrelate to shave off some time.
function c = xcorrelate(a,b)
%  c = xcorrelate(a,b)
%
%
%   Two-dimensional cross-correlation using Fourier transforms.

%This function is based upon an adaptation of the xcorrf tool written by 
%R. Johnson. It has been adapted for use as part of GIV.


  if nargin<3
    pad='yes';
  end
  
  
  [ma,na] = size(a);
  if nargin == 1
    b = a;
  end
  [mb,nb] = size(b);
  %       make reverse conjugate of one array
  b = conj(b(mb:-1:1,nb:-1:1));
  
  if strcmp(pad,'yes');
    %       use power of 2 transform lengths
    mf = 2^nextpow2(ma+mb);
    nf = 2^nextpow2(na+nb);
    at = fft2(b,mf,nf);
    bt = fft2(a,mf,nf);
  elseif strcmp(pad,'no');
    at = fft2(b);
    bt = fft2(a);
  else
    disp('Wrong input to xcorrelate'); return
  end
  
  %       multiply transforms then inverse transform
  c = ifft2(at.*bt);
  %       make real output for real input
  if ~any(any(imag(a))) & ~any(any(imag(b)))
    c = real(c);
  end
  %  trim to standard size
  
  if strcmp(pad,'yes');
    c(ma+mb:mf,:) = [];
    c(:,na+nb:nf) = [];
  elseif strcmp(pad,'no');
    c=fftshift(c(1:end-1,1:end-1));
    
   c(ma+mb:mf,:) = [];
   c(:,na+nb:nf) = [];
  end


end
end