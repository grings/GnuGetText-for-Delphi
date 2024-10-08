(* Delphi Unit (Unicode)
   procedures and functions for file and directory processing
   ==========================================================

   � Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   Vers. 1 -   Feb. 2010
         2.0 - Nov. 2011: functions for optional debug logging (Compiler switch: trace)
                          new function "CheckForParsePoint"
         2.1 - May  2012: changed "OpenDebugLog"
         2.2 - Jun. 2012: new function "FileTimeToFileAge"
                          Check for identical filenames in CopyFileTS
         2.3 - Jul. 2012: Timestamp routines fixed for unvalid DateTime
         2.4 - Oct. 2012: added overload functions "SetDirectoryAge" and
                          "SetFileAge" with FileTime argument
         2.5 - Dec. 2012: "FollowLink" added to "GetFileTimestamps" and "GetDirTimestamps", 
                          new functions "FileDate", "FileTimeStamp" and "DirectoryTimeStamp"
         2.6 - Jan. 2013: LastAccesTime added to SetFileTimestamps
         2.7 - Apr. 2013: "DeleteMatchingFiles" returns number of deleted files,
                          new function "DeleteOlderFiles"
         2.8 - Jun. 2013: new function "LocalFileTimeToDateTime",
                          no function with "SetDirectoryAge" on root paths
         3.0 - Jul. 2013: new function "CopyFileAcl"
                          added all file and directory related functions from JrUtils
         3.1 - Apr. 2015: Updated: Reparse points and junctions
         4.0 - Jan. 2016: reorganized code, e.g. use of GetFileAttributesEx
                          handling of extended-length paths in unit XlFileUtils
                          new file for resource strings: FileConsts
         4.1 - Jan. 2017: several changes and enhancements
         4.2 - Jan. 2019: new functtion: GetExistingParentPath => PathUtils 2023/02
         4.3 - Jan. 2020: new function: RemoveFirstDir => PathUtils 2023/02
         4.4 - Feb. 2023: extensions to be used with portable devices (June 2022)
                          moved to ExtFileUtils

   last modified: February 2023
   *)

unit FileUtils;

interface

uses WinApi.Windows, System.Classes, System.SysUtils;

const
  FILE_WRITE_ATTRIBUTES = $0100;
  defBlockSize = 256*1024;

  faAllFiles  = faArchive+faReadOnly+faHidden+faSysfile+faNormal;
  faNoArchive = faReadOnly+faHidden+faSysfile;
  faSuperHidden = faHidden+faSysfile;  //  hidden system dirs and files
  faDirReadonly = faDirectory or faReadOnly;

type
{ ------------------------------------------------------------------- }
  TInt64 = record
    case integer of
    0: (AsInt64 : int64);
    1: (Lo, Hi  : Cardinal);
    2: (Cardinals: array [0..1] of Cardinal);
    3: (Words: array [0..3] of Word);
    4: (Bytes: array [0..7] of Byte);
    5 :(FileTime : TFileTime);
    end;

  TFileTimestamps = record
    Valid: boolean;
    CreationTime, LastAccessTime, LastWriteTime: TFileTime;
    procedure Reset;
    procedure SetTimeStamps(CTime, MTime: TDateTime);
  end;

  TFileInfo = record
    Name     : string;
    CreationTime,
    DateTime : TDateTime;
    FileTime : TFileTime;
    Size     : int64;
    Attr,Res : cardinal;
    end;

  TReparseType = (rtNone,rtJunction,rtSymbolic);

{ ------------------------------------------------------------------- }
// similar to TFileStream but different error handling
  TExtFileStream = class(THandleStream)
  strict private
    FFileName: string;
  public
    constructor Create(const AFileName: string; Mode: Word); overload;
    constructor Create(const AFileName: string; Mode: Word; Rights: Cardinal); overload;
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint; var ReadCount : Longint): integer; overload;
    function Write(const Buffer; Count: Longint; var WriteCount : Longint): integer; overload;
    property FileName: string read FFileName;
  end;

{ ---------------------------------------------------------------- }
  EExtFileStreamError = class(EInOutError)
  public
    constructor Create(const Msg: string; FError : integer);
    constructor CreateResFmt(ResStringRec : PResStringRec; const Args: array of const; FError : integer);
    end;

   ECopyError = class(EExtFileStreamError);

{ ---------------------------------------------------------------- }
// Write opt. Debug Log
{$IFDEF Trace}
procedure OpenDebugLog (Filename : string);
procedure WriteDebugLog (const DebugText: string);
procedure CloseDebugLog;
{$ENDIF}

{ ------------------------------------------------------------------- }
// create new file and write BOM
function WriteUtf8Bom (const Filename : string) : integer;
// check if file has leading BOM
function CheckUtf8Bom (const Filename : string) : integer;

{ ---------------------------------------------------------------- }
// convert Filetime to Delphi time (TDateTime)
function FileTimeToDateTime (ft : TFileTime; var dt : TDateTime) : boolean; overload;
function FileTimeToDateTime (ft : TFileTime) : TDateTime; overload;
function GetFileTimeToDateTime (ft : TFileTime) : TDateTime;
function FileTimeToLocalDateTime (ft : TFileTime; var dt : TDateTime) : boolean; overload;
function FileTimeToLocalDateTime (ft : TFileTime) : TDateTime; overload;
function GetFileDateToDateTime(FileDate: LongInt): TDateTime;

// convert Delphi time (TDateTime) to Filetime
function DateTimeToFileTime (dt : TDateTime) : TFileTime;
function LocalDateTimeToFileTime (dt : TDateTime) : TFileTime;

// convert Delphi time to Unix time and reverse
function DateTimeToUnixTime (dt : TDateTime) : cardinal;
function UnixTimeToDateTime (ut : cardinal) : TDateTime;

// convert Fileage to Unix time
function FileAgeToUnixTime (Age : cardinal) : cardinal;
function FileTimeToFileAge (ft : TFileTime) : cardinal;

// convert Filetime to Unix time and reverse
function FileTimeToUnixTime (ft : TFileTime) : cardinal;
function UnixTimeToFileTime (ut : cardinal) : TFileTime;

// convert Filetime to seconds
function FileTimeToSeconds (ft : TFileTime) : cardinal;

// convert Filetime to string
function FileTimeToString (ft : TFileTime) : string;

// set Filetime to 0
function ResetFileTime : TFileTime;

{ ---------------------------------------------------------------- }
// get file size, last write time and attributes
function GetFileInfo (const FileName : string; var FSize : int64;
                      var FTime : TFileTime; var FAttr : cardinal;
                      IncludeDirs : boolean = false) : boolean; overload;

function GetFileInfo (const FileName : string; var FSize : int64;
                      var FTime : TFileTime; var FAttr,FReserved : cardinal;
                      IncludeDirs : boolean = false) : boolean; overload;

function GetFileInfo (const FileName : string; var FileInfo : TFileInfo;
                      IncludeDirs : boolean = false) : boolean; overload;

// get file version, description, ...
function GetFileInfoString (const Filename : string) : string;

// get time (UTC) of last file write
function GetFileLastWriteDateTime(const FileName: string): TDateTime;

// Get time stamp of file or directory (see FileAge)
function GetFileDateTime (const FileName : string; FollowLink : Boolean = True) : TDateTime;
function GetDirectoryDateTime(const FileName: string; FollowLink : Boolean = True): TDateTime;

// get time (UTC) of last file write
function GetFileLastWriteTime(const FileName: string) : TFileTime;

// set time (UTC) of last file write
function SetFileLastWriteDateTime(const FileName: string; FileTime : TDateTime) : integer;

// set time (UTC) of last file write
function SetFileLastWriteTime(const FileName: string; FileTime : TFileTime;
                              CheckTime : boolean = false) : integer;

// get file timestamps (UTC)
function GetFileTimestamps(const FileName: string; FollowLink: Boolean = True): TFileTimestamps;

// get directory timestamps (UTC)
function GetDirTimestamps(const DirName: string; FollowLink: Boolean = True): TFileTimestamps;

// get time (UTC) of last directory change
function GetDirLastChangeTime(const DirName: string): TFileTime;

// get file or directory timestamps (UTC) from FindData
function GetTimestampsFromFindData(const FindData : TWin32FindData) : TFileTimestamps;

// set file timestamps (UTC)
function SetFileTimestamps (const FileName: string; Timestamps : TFileTimestamps;
                            CheckTime,SetCreationTime : boolean; FollowLink : Boolean = True) : integer;

// get DOS file age from file data
function GetFileAge (LastWriteTime : TFileTime) : integer; overload;

function DirectoryAge(const DirName: string; FollowLink : Boolean = True): Integer; overload;
function DirectoryAge(const DirName: string; out FileDateTime: TDateTime; FollowLink : Boolean = True): Boolean; overload;

// Set time stamp of file or directory (see FileSetDate)
function SetFileAge(const FileName: string; Age: Integer; FollowLink : Boolean = True): Integer; overload;
function SetDirectoryAge(const DirName: string; Age: Integer; FollowLink : Boolean = True): Integer; overload;

function SetFileAge(const FileName: string; Age: FileTime; FollowLink : Boolean = True): Integer; overload;
function SetDirectoryAge(const DirName: string; Age: FileTime; FollowLink : Boolean = True): Integer; overload;

{ ---------------------------------------------------------------- }
// convert file attribute to string
function FileAttrToString(Attr : word) : string;

// Clear = true  : clear given attributes
//       = false : set given attributes
function FileChangeAttr (const FileName: string; Attr: cardinal; Clear : boolean;
                         FollowLink: Boolean = True) : Integer;

// read file data (WIN32_FIND_DATA)
function GetFindData(const FileName : string; var FileData : TWin32FindData) : boolean;

function GetFileAttrData(const FileName : string; var FileData : TWin32FileAttributeData;
                     FollowLink: Boolean = True) : integer;

{ ---------------------------------------------------------------- }
// get file size as int64
function GetFileSize (const FileData: TWin32FindData) : int64; overload; deprecated; // from Delphi 7
function GetFileSize (const FileData: TWin32FileAttributeData) : int64; overload;
function LongFileSize (const FileName : string) : int64;

// Convert SearchRec to FileInfo
function SearchRecToFileInfo (SearchRec : TSearchRec) : TFileInfo;

// set timestamp and attributes from SearcRec
function SetTimestampAndAttr(const FileName : string; SearchRec : TSearchRec) : integer;

{ ---------------------------------------------------------------- }
// Delete file even if readonly
function EraseFile(const FileName: string): Boolean;

// Delete file if exists
function DeleteExistingFile(const Filename : string) : boolean;

// Delete all matching files in directory
function DeleteMatchingFiles(const APath,AMask : string) : integer;

// Delete all files in directory older than date
function DeleteOlderFiles(const APath,AMask : string; ADate : TDateTime) : integer;

{ ---------------------------------------------------------------- }
// Check for existing text file
function ExistsFile (var f : TextFile) : boolean;

// Check if a directory contains a file matching the given mask
function FileMatchesMask (const Dir,Mask : string) : string;

{ ---------------------------------------------------------------- }
// Copy file without timestamp and attributes *)
function CopyFileData (const SrcFilename,DestFilename : string;
                       BlockSize : integer = defBlockSize): cardinal;

// Copy file with timestamp and attributes *)
procedure CopyFileTS (const SrcFilename,DestFilename : string;
                      AAttr : integer = -1; BlockSize : integer = defBlockSize);

{ ---------------------------------------------------------------- }
// Copy files from one directory to another
function CopyFiles (const FromDir,ToDir,AMask : string; OverWrite : boolean) : boolean;

{ ---------------------------------------------------------------- }
// Copy file permissions (ACL)
function CopyFileAcl (const SrcFilename,DestFilename : string) : cardinal;

// Copy alternate file streams
function CopyAlternateStreams (const SrcFilename,DestFilename : string): cardinal;

// Copy file attributes and timestamps
function CopyAttrAndTimestamp (const SrcFilename,DestFilename : string) : cardinal;

{ ---------------------------------------------------------------- }
// get the type of the reparse point (junction or symbolic)
function GetReparsePointType(const FileName : string) : TReparseType;

function GetLinkPath (const FileName: string) : string;

// Check if reparse point and return linked path
function CheckForReparsePoint (const Path : string; Attr : integer;
                               var LinkPath : string; var RpType : TReparseType) : boolean; overload;
function CheckForReparsePoint (const Path : string; Attr : integer;
                               var LinkPath : string) : boolean; overload;

// Check for reparse point
function IsReparsePoint (Attr : integer) : boolean; overload;
function IsReparsePoint (const Path : string) : boolean; overload;

// Pathname of reparse point
function GetJunction (const Path : string) : string;
function CreateJunction (const Source,Destination: string) : integer;

{ ---------------------------------------------------------------- }
// Check if file is read-only
function IsFileReadOnly (const fName : string) : boolean;

// Check if file is in use
function IsFileInUse (const fName : string) : boolean;

// Check if path is a directory
function IsDirectory (const APath : string) : boolean;

// Check if directory is empty
function IsEmptyDir (const Directory : string) : boolean;

// Check if directory has subdirectories
function HasNoSubDirs (const Directory : string) : boolean;

// Delete empty directories
procedure DeleteEmptyDirectories (const Directory : string);

{ ---------------------------------------------------------------- }
// Check if directory has specified file type
function HasFileType (const Directory,Ext : string) : boolean;

{ ---------------------------------------------------------------- }
// Count files in directory and calculate the resulting volume
procedure CountFiles (const Base,Dir,Ext : string; IncludeSubDir : boolean;
                      var FileCount : integer; var FileSize : int64); overload;
procedure CountFiles (const Base,Dir : string; IncludeSubDir : boolean;
                      var FileCount : integer; var FileSize : int64); overload;
function DirFiles (const Directory : string; IncludeSubDir : boolean; Ext : string = '') : integer;
function DirSize (const Directory : string; IncludeSubDir : boolean; Ext : string = '') : int64;

{ ---------------------------------------------------------------- }
// Delete a directory including all subdirectories and files
procedure DeleteDirectory (const Base,Dir           : string;
                           DeleteRoot               : boolean;
                           var DCount,FCount,ECount : cardinal); overload;
function DeleteDirectory (const Directory : string;
                          DeleteRoot      : boolean = true) : boolean; overload;

{ ---------------------------------------------------------------- }
// Check if a directory is accessible
function CanAccess (const Directory : string; var ErrorCode : integer) : boolean; overload;
function CanAccess (const Directory : string) : boolean; overload;

// Returns true if GetLastError = ERROR_FILE_NOT_FOUND
function FileNotFound (const FileName : string) : boolean;

{ ---------------------------------------------------------------- }
implementation

uses System.StrUtils, Winapi.PsAPI, WinApi.AccCtrl, WinApi.AclApi,
  System.RTLConsts, WinApiUtils, FileConsts, ExtSysUtils, PathUtils;

{ ---------------------------------------------------------------- }
{ TExtFileStream }

constructor TExtFileStream.Create(const AFileName: string; Mode: Word);
begin
  Create(AFilename, Mode, 0);
end;

constructor TExtFileStream.Create(const AFileName: string; Mode: Word; Rights: Cardinal);
var
  LShareMode : Word;
  err        : dword;
begin
  if (Mode and fmCreate = fmCreate) then
  begin
    LShareMode := Mode and $FF;
    if LShareMode = $FF then
      LShareMode := fmShareExclusive; // For compat in case $FFFF passed as Mode
    inherited Create(FileCreate(AFileName, LShareMode, Rights));
    if FHandle = INVALID_HANDLE_VALUE then begin
      err:=GetLastError;
      raise EExtFileStreamError.CreateResFmt(@SFCreateErrorEx,[ExpandFileName(AFileName),SysErrorMessage(err)],err);
      end;
    end
  else begin
    inherited Create(FileOpen(AFileName, Mode));
    if FHandle = INVALID_HANDLE_VALUE then begin
      err:=GetLastError;
      raise EExtFileStreamError.CreateResFmt(@SFOpenErrorEx, [ExpandFileName(AFileName), SysErrorMessage(err)],err);
      end;
    end;
  FFileName := AFileName;
  end;

destructor TExtFileStream.Destroy;
begin
  if FHandle <> INVALID_HANDLE_VALUE then FileClose(FHandle);
  inherited Destroy;
end;

function TExtFileStream.Read(var Buffer; Count: Longint; var ReadCount : Longint) : integer;
begin
  ReadCount:=FileRead(FHandle, Buffer, Count);
  if ReadCount<0 then Result:=GetLastError else Result:=ERROR_SUCCESS;
  end;

function TExtFileStream.Write(const Buffer; Count: Longint; var WriteCount : Longint): integer;
begin
  WriteCount:=FileWrite(FHandle, Buffer, Count);
  if WriteCount<0 then Result:=GetLastError else Result:=ERROR_SUCCESS;
  end;

{ ---------------------------------------------------------------- }
constructor EExtFileStreamError.Create(const Msg: string; FError : integer);
begin
  inherited Create (Msg);
  ErrorCode:=FError;
  end;

constructor EExtFileStreamError.CreateResFmt(ResStringRec : PResStringRec; const Args: array of const; FError : integer);
begin
  inherited Create (Format(LoadResString(ResStringRec), Args));
  ErrorCode:=FError;
  end;

{ ------------------------------------------------------------------- }
const
  Utf8Bom : array[0..2] of byte = ($EF,$BB,$BF);

// create new file and write BOM
function WriteUtf8Bom (const Filename : string) : integer;
var
  fp    : file;
  n     : integer;
begin
  assignfile(fp,Filename);
  {$I-} rewrite(fp,1) {$I+};
  Result:=IOResult;
  if Result=0 then begin
    BlockWrite(fp,Utf8Bom,3,n);
    CloseFile(fp);
    end;
  end;

// check if file has leading BOM
// Result = -1 : has BOM
//        =  0 : no BOM
//        >  0 : Error
function CheckUtf8Bom (const Filename : string) : integer;
var
  fp    : file;
  n     : integer;
  Bom   : array[0..2] of byte;
begin
  assignfile(fp,Filename);
  {$I-} reset(fp,1) {$I+};
  Result:=IOResult;        // IOResult 0 or >= 100
  if Result=0 then begin
    BlockRead(fp,Bom,3,n);
    if (n=3) and CompareMem(@Bom[0],@Utf8Bom[0],3) then Result:=-1
    else Result:=0;
    CloseFile(fp);
    end;
  end;

{ ---------------------------------------------------------------- }
// following routine comes from SysUtils
type
  OBJECT_INFORMATION_CLASS = (ObjectBasicInformation, ObjectNameInformation,
    ObjectTypeInformation, ObjectAllTypesInformation, ObjectHandleInformation);

  UNICODE_STRING = packed record
    Length: Word;
    MaximumLength: Word;
    Buffer:PWideChar;
  end;

  OBJECT_NAME_INFORMATION = record
    TypeName: UNICODE_STRING;
    Reserved: array[0..21] of ULONG; // reserved for internal use
  end;

  TNtQueryObject = function (ObjectHandle: THandle;
    ObjectInformationClass: OBJECT_INFORMATION_CLASS; ObjectInformation: Pointer;
    Length: ULONG; ResultLength: PDWORD): THandle; stdcall;

var
  NTQueryObject: TNtQueryObject;

// from SysUtils (see bugfix in ExpandVolumeName
function GetFileNameFromSymLink(const FileName: string; var TargetName: string): Boolean;

  // Use this function to get the final target file name of a symbolic link.
  // It is the same as GetFinalPathNameByHandle but GetFinalPathNameByHandle
  // has some problems.
  function InternalGetFileNameFromHandle(Handle: THandle; var FileName: string; Flags: DWORD): Boolean;

    function ExpandVolumeName(const AFileName: string): string;
    var
      Drives, Temp: array[0..MAX_PATH + 1] of Char;
      P: PChar;
      Len: Integer;
      VolumeName: string;
    begin
      Len := GetLogicalDriveStrings(MAX_PATH, Drives);

      if Len > 0 then
      begin
        P := @Drives[0];

        repeat
          (P + 2)^ := #0;
          Len := Integer(QueryDosDevice(P, Temp, MAX_PATH));

          if Len > 0 then
          begin
            VolumeName := Temp;
            // changed JR 2018-03-22:
            // Pos(VolumeName, AFileName) returns value >0 e.g. for
            // VolumeName=\Device\HarddiskVolume1 and AFileName=\Device\HarddiskVolume10\..
            if Pos(IncludeTrailingPathDelimiter(VolumeName), AFileName) > 0 then
            begin
              Len := Length(VolumeName);
              Result := P + Copy(AFileName, Len + 1, Length(AFileName) - Len);
              Break;
            end;
          end;

          while P^ <> #0 do
            Inc(P);
          Inc(P, 2);

        until P = '';
      end;
    end;

    function GetObjectInfoName(Handle: THandle): string;
    const
      STATUS_SUCCESS = $00000000;
    var
      Info: ^OBJECT_NAME_INFORMATION;
      Status: THandle;
      Size: DWORD;
    begin
      Result := '';
      if not Assigned(NTQueryObject) then
        NTQueryObject := GetProcAddress(GetModuleHandle('NTDLL.DLL'), 'NtQueryObject'); // Do not localize

      if not Assigned(NTQUeryObject) then
        Exit;

      NtQueryObject(Handle, ObjectNameInformation, nil, 0, @Size);
      GetMem(Info, size);
      try
        Status := NTQueryObject(Handle, ObjectNameInformation, Info, Size, @Size);

        if Status = STATUS_SUCCESS then
          Result := Info.TypeName.Buffer;
      finally
        FreeMem(Info);
      end;
    end;

  var
    FileMapHandle: THandle;
    FileSizeHigh, FileSizeLow: DWORD;
    Memory: Pointer;
    Buffer: array[0..MAX_PATH + 1] of Char;
  begin
    Result := False;
    FileName := '';
    FileSizeHigh := 0;
    FileSizeLow := WinApi.Windows.GetFileSize(Handle, @FileSizeHigh);

    // GetFinalPathNameByHandle is broken so use other techniques to retrieve
    // the file's name.
    if (FileSizeLow = 0) and (FileSizeHigh = 0) and CheckWin32Version(6, 0) then
    begin
      if GetFinalPathNameByHandle(Handle, Buffer, MAX_PATH, VOLUME_NAME_NT) > 0 then
      begin
        FileName := ExpandVolumeName(Buffer);
        Exit(True);
      end;
    end;

    if (FileSizeLow <> 0) or (FileSizeHigh <> 0) then
    begin
      FileMapHandle := CreateFileMapping(Handle, nil, PAGE_READONLY, 0, 1, nil);

      if FileMapHandle <> ERROR_FILE_INVALID then
      begin
        try
          Memory := MapViewOfFile(FileMapHandle, FILE_MAP_READ, 0, 0, 1);

          if (Memory <> nil) then
          begin
            try
              if (GetMappedFileName(GetCurrentProcess(), Memory, Buffer, MAX_PATH) > 0) then
              begin
                FileName := ExpandVolumeName(Buffer);
                Result := True;
              end;
            finally
              UnmapViewOfFile(Memory);
            end;
          end;
        finally
          CloseHandle(FileMapHandle);
        end;
      end;
    end;

    if not Result then
    begin
      // If the file is zero size or is a directory then CreateFileMapping will
      // fail. Try using ZwQuerySystemInformation and ZwQueryObject.
      FileName := GetObjectInfoName(Handle);
      if FileName <> '' then
      begin
        FileName := ExpandVolumeName(FileName);
        Result := True;
      end;
    end;
  end;

var
  Handle: THandle;
  Flags: DWORD;
  Code: Cardinal;
begin
  Result := False;

  if CheckWin32Version(6, 0) then
  begin
    Code := GetFileAttributes(PChar(FileName));
    if (Code <> INVALID_FILE_ATTRIBUTES) and ((faSymLink and Code) <> 0) then
    begin
      if faDirectory and Code <> 0 then
        Flags := FILE_FLAG_BACKUP_SEMANTICS
      else
        Flags := 0;

      Handle := CreateFile(PChar(FileName), GENERIC_EXECUTE, FILE_SHARE_READ, nil,
        OPEN_EXISTING, Flags, 0);

      if Handle <> INVALID_HANDLE_VALUE then begin
        try
          Result := InternalGetFileNameFromHandle(Handle, TargetName, Flags);
        finally
          CloseHandle(Handle);
          end;
        end
      end;
    end;
  end;

{ ------------------------------------------------------------------- }
// read file data
function GetFindData(const FileName : string; var FileData : TWin32FindData) : boolean;
var
  Handle: THandle;
begin
  Handle:=FindFirstFile(PChar(FileName),FileData);
  Result:=Handle<>INVALID_HANDLE_VALUE;
  if Result then begin
    WinApi.Windows.FindClose(Handle);
    Result:=(FileData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0;
    end;
  end;

function GetFileAttrData(const FileName : string; var FileData : TWin32FileAttributeData;
                     FollowLink: Boolean = True) : integer;
var
  TargetName  : string;
  FindData : TWin32FindData;
  ok : boolean;
begin
  ok:=GetFileAttributesEx(PChar(FileName),GetFileExInfoStandard,@FileData);
  if ok then begin
    if (FileData.dwFileAttributes and faSymLink <> 0) and FollowLink then begin
      if GetFileNameFromSymLink(FileName, TargetName) then begin
        if IsRelativePath(TargetName) then
          TargetName:=IncludeTrailingPathDelimiter(ExtractFilePath(FileName))+TargetName;
        ok:=GetFileAttributesEx(PChar(TargetName),GetFileExInfoStandard,@FileData);
        end;
      end;
    Result:=ERROR_SUCCESS;
    end;
  if not ok then begin
    Result:=GetLastError;
    case Result of
      ERROR_SHARING_VIOLATION,
      ERROR_LOCK_VIOLATION:
        if not GetFindData(FileName,FindData) then Result:=ERROR_SHARING_VIOLATION
      else begin
        Move(FindData,FileData,SizeOf(TWin32FileAttributeData));
        Result:=ERROR_SUCCESS;
        end;
      end;
    end;
  end;

{ ---------------------------------------------------------------- }
// get time (UTC) of last file write
function GetFileLastWriteTime(const FileName: string): TFileTime;
var
  FileData : TWin32FileAttributeData;
begin
  if GetFileAttrData(FileName,FileData)=ERROR_SUCCESS then Result:=FileData.ftLastWriteTime
  else Result:=ResetFileTime;
  end;

// set time (UTC) of last file write
// CheckTime = true: Change FileTime to actual time if out of range
function SetFileLastWriteTime(const FileName: string; FileTime : TFileTime;
                              CheckTime : boolean) : integer;
var
  Handle   : THandle;
  dt       : TDateTime;
begin
  if CheckTime then begin
    if not FileTimeToDateTime(FileTime,dt) or (dt>Now+1) then FileTime:=DateTimeToFileTime(Now);
    end;
  Handle:=FileOpen(FileName,fmOpenWrite);
  if Handle=THandle(-1) then Result:=GetLastError
  else begin
    if SetFileTime(Handle,nil,nil,@FileTime) then Result:=0
    else Result:=GetLastError;
    FileClose(Handle);
    end;
  end;

{ ---------------------------------------------------------------- }
// get time (UTC) of last file write
function GetFileDateTime (const FileName: string; FollowLink : Boolean = True) : TDateTime;
begin
  if not FileAge(FileName,Result,FollowLink) then Result:=0;
  end;

{ ---------------------------------------------------------------- }
// get time (UTC) of last file write
function GetFileLastWriteDateTime(const FileName: string): TDateTime;
var
  FileData : TWin32FileAttributeData;
begin
  if (GetFileAttrData(FileName,FileData)<>ERROR_SUCCESS)
    or not FileTimeToDateTime(FileData.ftLastWriteTime,Result) then Result:=0;
  end;

// set time (UTC) of last file write
function SetFileLastWriteDateTime(const FileName: string; FileTime : TDateTime) : integer;
var
  f   : THandle;
  ft  : TFileTime;
begin
  f:=CreateFile(PChar(FileName),FILE_WRITE_ATTRIBUTES,0,nil, OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,0);
  if f=THandle(-1) then Result:=GetLastError
  else begin
    ft:=DateTimeToFileTime(FileTime);
    if SetFileTime(f,nil,nil,@ft) then Result:=NO_ERROR else Result:=GetLastError;
    FileClose(f);
    end;
  end;

{ ---------------------------------------------------------------- }
// get file/directory size, last write time, attributes and reparse point tags
function GetFileInfo (const FileName : string; var FileInfo : TFileInfo;
                      IncludeDirs : boolean = false) : boolean; overload;
var
  FindData : TSearchRec;
  FindResult : integer;
begin
  Result:=false;             // does not exist
  with FileInfo do begin
    Name:='';
    DateTime:=Now;
    CreationTime:=Now;
    FileTime:=DateTimeToFileTime(DateTime);
    Size:=0;
    Attr:=INVALID_FILE_ATTRIBUTES;
    Res:=0;
    end;
  FindResult:=FindFirst(FileName,faAnyFile,FindData);
  if (FindResult=0) and (IncludeDirs or (FindData.Attr and faDirectory=0)) then begin
    FileInfo:=SearchRecToFileInfo(FindData);
    Result:=true;
    end;
  FindClose(FindData);
  end;

function GetFileInfo (const FileName : string; var FSize : int64;
                      var FTime : TFileTime; var FAttr,FReserved : cardinal;
                      IncludeDirs : boolean = false) : boolean;
var
  fi : TFileInfo;
begin
  Result:=GetFileInfo(FileName,fi,IncludeDirs);
  with fi do begin
    FSize:=Size; FTime:=FileTime;
    FAttr:=Attr; FReserved:=Res;
    end;
  end;

function GetFileInfo(const FileName : string; var FSize : int64;
                     var FTime : TFileTime; var FAttr : cardinal;
                     IncludeDirs : boolean = false) : boolean;
var
  n : cardinal;
begin
  Result:=GetFileInfo(FileName,FSize,FTime,FAttr,n,IncludeDirs);
  end;

{ ---------------------------------------------------------------- }
function GetFileInfoString (const Filename : string) : string;
var
  VersInfo : TFileVersionInfo;
begin
  Result:='';
  if GetFileVersion (Filename,VersInfo) then with VersInfo do begin
    if length(Description)>0 then Result:=Result+rsDescription+Description+sLineBreak;
    if length(Company)>0 then Result:=Result+rsCompany+Company+sLineBreak;
    if length(Copyright)>0 then Result:=Result+rsCopyright+Copyright+sLineBreak;
    if length(Version)>0 then Result:=Result+rsVersion+Version+sLineBreak;
    end
  else Result:=rsNoFileInfo+sLineBreak;
  with FormatSettings do
    Result:=Result+rsFileDate+FormatDateTime(ShortDateFormat+' '+ShortTimeFormat,GetFileLastWriteDateTime(Filename));
  end;

{ ---------------------------------------------------------------- }
// set timestamp and attrtibutes from SearcRec
// Result = 0 : ok
//        > 0 : sytem error code - setting timestamp failed
//        < 0 : -sytem error code - setting attribute failed
function SetTimestampAndAttr(const FileName : string; SearchRec : TSearchRec) : integer;
begin
  with SearchRec do begin
    Result:=SetFileLastWriteDateTime(Filename,TimeStamp);
    if Result=NO_ERROR then Result:=-FileChangeAttr(FileName,Attr,false);
    end;
  end;

{ ---------------------------------------------------------------- }
// get file or directory timestamps (UTC) from FindData
function GetTimestampsFromFindData(const FindData : TWin32FindData) : TFileTimestamps;
begin
  with Result do begin
    CreationTime:=FindData.ftCreationTime;
    LastAccessTime:=FindData.ftLastAccessTime;
    LastWriteTime:=FindData.ftLastWriteTime;
    Valid:=true;
    end;
  end;

// get file or directory timestamps (UTC)
function GetTimestamps(const AName : string; ADir : boolean; FollowLink : Boolean = True) : TFileTimestamps;
var
  FileData   : TWin32FileAttributeData;
  ok         : boolean;
begin
  ok:=GetFileAttrData(AName,FileData,FollowLink)=ERROR_SUCCESS;
  if ok and ((FileData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY =0) xor ADir) then begin
    with Result do begin
      CreationTime:=FileData.ftCreationTime;
      LastAccessTime:=FileData.ftLastAccessTime;
      LastWriteTime:=FileData.ftLastWriteTime;
      Valid:=true;
      Exit;
      end;
    end
  else begin
    FillChar(Result,sizeof(TFileTimestamps),0); // error
    Result.Valid:=false;
    end;
  end;

// get file timestamps (UTC)
function GetFileTimestamps(const FileName : string; FollowLink : Boolean = True): TFileTimestamps;
begin
  Result:=GetTimestamps(FileName,false,FollowLink);
  end;

// get directory timestamps (UTC)
function GetDirTimestamps(const DirName : string; FollowLink : Boolean = True): TFileTimestamps;
begin
  Result:=GetTimestamps(DirName,true,FollowLink);
  end;

// get time (UTC) of last directory change
function GetDirLastChangeTime(const DirName: string): TFileTime;
begin
  Result:=GetTimestamps(DirName,true).LastWriteTime;
  end;

// set file or directory timestamps (UTC)
// CheckTime = true: Change FileTime to actual time if out of range
// SetCreationTime = true: Copy timestamp ftCreationTime
function SetFileTimestamps (const FileName: string; Timestamps : TFileTimestamps;
                            CheckTime,SetCreationTime : boolean; FollowLink : Boolean = True) : integer;
var
  Handle   : THandle;
  tm       : TFiletime;
  dt       : TDateTime;
  fn,tn    : string;
  ok       : boolean;
begin
  tm:=DateTimeToFileTime(Now);
  with Timestamps do if Valid then begin
    if CheckTime then begin
      if not FileTimeToDateTime(CreationTime,dt) or (dt>Now+1) then CreationTime:=tm;
      if not FileTimeToDateTime(LastAccessTime,dt) or (dt>Now+1) then LastAccessTime:=tm;
      if not FileTimeToDateTime(LastWriteTime,dt) or (dt>Now+1) then LastWriteTime:=tm;
      end;
    end
  else begin
    CreationTime:=tm;
    LastAccessTime:=tm;
    LastWriteTime:=tm;
    end;

  fn:=FileName;
  if FollowLink then begin
    if ((faSymLink and GetFileAttributes(PChar(fn))) <> 0) and
        GetFileNameFromSymLink(fn,tn) then begin
      if IsRelativePath(tn) then
        fn:=IncludeTrailingPathDelimiter(ExtractFilePath(fn)) + tn
        else fn:=tn;
      end;
    end;

  Handle:=CreateFile(PChar(fn),FILE_WRITE_ATTRIBUTES,0,nil,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,0);
  if Handle=THandle(-1) then Result:=GetLastError
  else with Timestamps do begin
    if SetCreationTime then ok:=SetFileTime(Handle,@CreationTime,@LastAccessTime,@LastWriteTime)
    else ok:=SetFileTime(Handle,nil,nil,@LastWriteTime);
    if ok then Result:=NO_ERROR else Result:=GetLastError;
    FileClose(Handle);
    end;
  end;

{ ------------------------------------------------------------------- }
// convert Filetime to Delphi time (TDateTime)
function FileTimeToDateTime (ft : TFileTime; var dt : TDateTime) : boolean;
var
  st : TSystemTime;
begin
  Result:=false;
  if not (FileTimeToSystemTime(ft,st) and TrySystemTimeToDateTime(st,dt)) then dt:=Now
  else Result:=true;
  end;

function FileTimeToDateTime (ft : TFileTime) : TDateTime; overload;
begin
  if not FileTimeToDateTime(ft,Result) then Result:=EncodeDate(1980,1,1);
  end;

function GetFileTimeToDateTime (ft : TFileTime) : TDateTime;
begin
  FileTimeToDateTime(ft,Result);
  end;

function FileTimeToLocalDateTime (ft : TFileTime; var dt : TDateTime) : boolean;
var
  ftl : TFileTime;
begin
  Result:=FileTimeToLocalFileTime(ft,ftl);
  Result:=Result and FileTimeToDateTime(ftl,dt);
  end;

function FileTimeToLocalDateTime (ft : TFileTime) : TDateTime; overload;
begin
  if not FileTimeToLocalDateTime (ft,Result) then Result:=EncodeDate(1980,1,1);
  end;

// same as SysUtils.FileDateToDateTime but without exception
function GetFileDateToDateTime(FileDate: LongInt): TDateTime;
begin
  try
    Result:=FileDateToDateTime(FileDate);
  except
    on EConvertError do Result:=EncodeDate(1980,1,1);
    end;
  end;

// convert Delphi time (TDateTime) to Filetime
function DateTimeToFileTime (dt : TDateTime) : TFileTime;
var
  st : TSystemTime;
begin
  with st do begin
    DecodeDate(dt,wYear,wMonth,wDay);
    DecodeTime(dt,wHour,wMinute,wSecond,wMilliseconds);
    end;
  SystemTimeToFileTime(st,Result);
  end;

function LocalDateTimeToFileTime (dt : TDateTime) : TFileTime;
var
  ft : TFileTime;
begin
  ft:=DateTimeToFileTime(dt);
  LocalFileTimeToFileTime(ft,Result);
  end;

// get DOS file age from file data
function GetFileAge (LastWriteTime : TFileTime) : integer;
var
  LocalFileTime: TFileTime;
begin
  Result:=-1;
  if FileTimeToLocalFileTime(LastWriteTime,LocalFileTime) then begin
    if not FileTimeToDosDateTime(LocalFileTime,LongRec(Result).Hi,LongRec(Result).Lo) then
      Result:=-1;
    end;
  end;

{ ------------------------------------------------------------------- }
// convert Delphi time to Unix time (= seconds since 00:00:00 UTC, 1.1.1970) and reverse
function DateTimeToUnixTime (dt : TDateTime) : cardinal;
begin
  Result:=round(SecsPerDay*(dt-25569));
  end;

function UnixTimeToDateTime (ut : cardinal) : TDateTime;
begin
  Result:=ut/SecsPerDay+25569;
  end;

// convert Fileage to Unix time and reverse
function FileAgeToUnixTime (Age : cardinal) : cardinal;
var
  lft,ft : TFileTime;
begin
  if DosDateTimeToFileTime(LongRec(Age).Hi,LongRec(Age).Lo,lft)
    and LocalFileTimeToFileTime(lft,ft) then
      Result:=FileTimeToUnixTime(ft)
  else Result:=0;
  end;

function FileTimeToFileAge (ft : TFileTime) : cardinal;
begin
  if not FileTimeToDosDateTime(ft,LongRec(Result).Hi,LongRec(Result).Lo) then Result:=0;
  end;

// convert Filetime to Unix time and reverse
function FileTimeToUnixTime (ft : TFileTime) : cardinal;
var
  dt : TDateTime;
begin
  FileTimeToDateTime(ft,dt);
  Result:=DateTimeToUnixTime (dt);
  end;

function UnixTimeToFileTime (ut : cardinal) : TFileTime;
begin
  Result:=DateTimeToFileTime(UnixTimeTodateTime(ut));
  end;

// convert Filetime to seconds
function FileTimeToSeconds (ft : TFileTime) : cardinal;
begin
  Result:=TInt64(ft).AsInt64 div 10000000;
  end;

function ResetFileTime : TFileTime;
begin
  with Result do begin
    dwLowDateTime:=0; dwHighDateTime:=0;
    end;
  end;

// convert Filetime to string
function FileTimeToString (ft : TFileTime) : string;
var
  dt : TDateTime;
begin
  if FileTimeToDateTime(ft,dt) then Result:=DateTimeToStr(dt)
  else Result:='???';
  end;

{ ------------------------------------------------------------------- }
// get DOS time stamp of directory (similar to FileAge)
function DirectoryAge(const DirName: string; FollowLink : Boolean = True): Integer;
var
  dt : TDateTime;
begin
  if DirectoryAge(DirName,dt,FollowLink) then Result:=DateTimeToFileDate(dt)
  else Result:=-1;
  end;

function DirectoryAge(const DirName: string; out FileDateTime : TDateTime; FollowLink : Boolean = True): Boolean;
var
  FileData      : TWin32FileAttributeData;
  ok            : boolean;
begin
  Result:=False;
  ok:=GetFileAttrData(DirName,FileData)=ERROR_SUCCESS;
  if ok and (FileData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <>0) then
    Result:=FileTimeToLocalDateTime(FileData.ftLastWriteTime,FileDateTime);
  end;

function GetDirectoryDateTime(const FileName: string; FollowLink : Boolean = True): TDateTime;
begin
  if not DirectoryAge(FileName,Result,FollowLink) then Result:=0;
  end;

// Set DOS time stamp of directory
function SetDirectoryAge(const DirName: string; Age: Integer; FollowLink : Boolean = True): Integer;
begin
  Result:=SetFileAge(DirName,Age,FollowLink);
  end;

function SetFileAge(const FileName: string; Age: Integer; FollowLink : Boolean = True): Integer;
var
  LocalFileTime : TFileTime;
begin
  if DosDateTimeToFileTime(LongRec(Age).Hi,LongRec(Age).Lo,LocalFileTime) then
    Result:=SetFileAge(FileName,LocalFileTime,FollowLink)
  else Result:=GetLastError;
  end;

// Set timestamp stamp of directory
function SetDirectoryAge(const DirName: string; Age: FileTime; FollowLink : Boolean = True): Integer;
begin
  if IsRootPath(DirName) then Result:=NO_ERROR
  else Result:=SetFileAge(DirName,Age,FollowLink);
  end;

function SetFileAge(const FileName: string; Age: FileTime; FollowLink : Boolean = True) : Integer;
var
  f             : THandle;
  fn,TargetName : string;
  FileTime      : TFileTime;
begin
  fn:=FileName;
  if FollowLink then begin
    if ((faSymLink and GetFileAttributes(PChar(fn)))<>0) and
        GetFileNameFromSymLink(fn,TargetName) then begin
      if IsRelativePath(TargetName) then
        fn:=IncludeTrailingPathDelimiter(ExtractFilePath(fn)+TargetName)
        else fn:=TargetName;
      end;
    end;
  f:=CreateFile(PChar(fn),FILE_WRITE_ATTRIBUTES,0,nil,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,0);
  if f=THandle(-1) then Result:=GetLastError
  else begin
    if LocalFileTimeToFileTime(Age,FileTime) and SetFileTime(f, nil, nil, @FileTime)
      then Result:=NO_ERROR else Result:=GetLastError;
    FileClose(f);
    end;
  end;

{ ------------------------------------------------------------------- }
{ ------------------------------------------------------------------- }
// Delete file even if readonly
function EraseFile(const FileName: string) : Boolean;
begin
  if FileExists(FileName) then begin
    Result:=FileSetAttr(Filename,faArchive,false)=0;
    if Result then Result:=DeleteFile(FileName);
    end
  else Result:=true;
  end;

// Delete file if exists
function DeleteExistingFile(const Filename : string) : boolean;
begin
  if FileExists(Filename) then Result:=DeleteFile(Filename)
  else Result:=true;
  end;

// Delete all matching files in directory
function DeleteMatchingFiles(const APath,AMask : string) : integer;
var
  DirInfo    : TSearchRec;
  Findresult : integer;
begin
  Result:=0;
  FindResult:=FindFirst(SetDirName(APath)+AMask,faAllFiles,DirInfo);
  while (FindResult=0) do begin
    if EraseFile(SetDirName(APath)+DirInfo.Name) then inc(Result);
    FindResult:=FindNext(DirInfo)
    end;
  FindClose(DirInfo);
  end;

// Delete all files in directory older than date
function DeleteOlderFiles(const APath,AMask : string; ADate : TDateTime) : integer;
var
  DirInfo    : TSearchRec;
  Findresult : integer;
begin
  Result:=0;
  FindResult:=FindFirst(SetDirName(APath)+AMask,faAllFiles,DirInfo);
  while (FindResult=0) do begin
    if DirInfo.TimeStamp<ADate then begin
      if EraseFile(SetDirName(APath)+DirInfo.Name) then inc(Result);
      end;
    FindResult:=FindNext(DirInfo)
    end;
  FindClose(DirInfo);
  end;

//-----------------------------------------------------------------------------
// Check if a directory contains a file matching the given mask
function FileMatchesMask (const Dir,Mask : string) : string;
var
  FInfo      : TSearchRec;
begin
  Result:='';
  if FindFirst (SetDirName(Dir)+Mask,faArchive,FInfo)=0 then
    Result:=SetDirName(Dir)+FInfo.Name;
  System.Sysutils.FindClose (FInfo);
  end;

{ ---------------------------------------------------------------- }
// Check for existing text file
function ExistsFile (var f : TextFile) : boolean;
begin
  (*$i-*) reset (f) (*$i+*);
  Result:=ioresult=0;
  end;

{ ------------------------------------------------------------------- }
// Copy contents of file, no timestamp and no attributes
// Returns error code from GetLastError
function CopyFileData(const SrcFilename,DestFilename : string;
         BlockSize : integer = defBlockSize): cardinal;
var
  srcfile,destfile : TExtFileStream;
  FBuffer          : array of byte;
  NRead,NWrite     : Integer;
begin
  Result:=ERROR_SUCCESS;
  if AnsiSameText(SrcFilename,DestFilename) then Exit;
  try
    srcfile:=TExtFileStream.Create(SrcFilename,fmOpenRead+fmShareDenyNone);
  except
    on E:EExtFileStreamError do Result:=E.ErrorCode;
    end;
  if Result=ERROR_SUCCESS then begin
    try
      destfile:=TExtFileStream.Create(DestFilename,fmCreate);
    except
      on E:EExtFileStreamError do begin
        try srcfile.Free; except end;
        Result:=E.ErrorCode;
        end;
      end;
    end;
  if Result=ERROR_SUCCESS then begin
    SetLength(FBuffer,BlockSize);
    try
      repeat
        Result:=srcfile.Read(FBuffer[0],BlockSize,NRead);
        if Result=ERROR_SUCCESS then begin
          Result:=destfile.Write(FBuffer[0],NRead,NWrite);
          if (Result=ERROR_SUCCESS) and (NWrite<NRead) then Result:=ERROR_DISK_FULL; // Ziel-Medium voll
          end;
        until (NRead<BlockSize) or (Result<>ERROR_SUCCESS);
    finally
      try srcfile.Free; destfile.Free; except end;
      FBuffer:=nil;
      end;
    end;
  end;

{ ------------------------------------------------------------------- }
// Copy file with timestamp and attributes
// AAttr = -1: copy original attributes
// raise exception on error
procedure CopyFileTS (const SrcFilename,DestFilename : string;
                      AAttr : integer = -1; BlockSize : integer = defBlockSize);
var
  srcfile, destfile : TExtFileStream;
  FTime             : TFileTime;
  Buffer            : pointer;
  NRead,NWrite,ec   : Integer;
  Attr              : word;
begin
  if AnsiSameText(srcfilename,destfilename) then Exit;
  if FileExists(srcfilename) and (length(destfilename)>0) then begin
    GetMem(Buffer,BlockSize);
    try
      FTime:=GetFileLastWriteTime(srcfilename);
      if AAttr<0 then Attr:=FileGetAttr(srcfilename) else Attr:=AAttr;
      try
        srcfile:=TExtFileStream.Create(srcfilename,fmOpenRead+fmShareDenyNone);
      except
        on E:EExtFileStreamError do
          raise ECopyError.Create (TryFormat(rsErrOpening,[srcfilename]),E.ErrorCode);
        end;
      // Ziel immer �berschreiben
      if FileExists(destfilename) then begin
        ec:=FileSetAttr(destfilename,faArchive);
        if ec<>ERROR_SUCCESS then begin
          try srcfile.Free; except end;
          raise ECopyError.Create (TryFormat(rsErrCreating,[destfilename]),ec);
          end;
        end;
      try
        destfile:=TExtFileStream.Create(destfilename,fmCreate);
      except
        on E:EExtFileStreamError do begin
          try srcfile.Free; except end;
          raise ECopyError.Create (TryFormat(rsErrCreating,[destfilename]),E.ErrorCode);
          end;
        end;
      try
        repeat
          ec:=srcfile.Read(Buffer^,BlockSize,NRead);
          if ec<>ERROR_SUCCESS then
            raise ECopyError.Create (TryFormat(rsErrReading,[srcfilename]),ec);
          ec:=destfile.Write(Buffer^,NRead,NWrite);
          if ec<>ERROR_SUCCESS then
            raise ECopyError.Create (TryFormat(rsErrWriting,[destfilename]),ec);
          if NWrite<NRead then  // Ziel-Medium voll
            raise ECopyError.Create (TryFormat(rsErrWriting,[destfilename]),ERROR_DISK_FULL);
          until NRead<BlockSize;
      finally
        try srcfile.Free; except; end;
        try destfile.Free; except; end;
        end;
      ec:=SetFileLastWriteTime(destfilename,FTime,true);
      if ec=ERROR_SUCCESS then begin
        ec:=FileSetAttr(destfilename,Attr);
        if ec<>ERROR_SUCCESS then
          raise ECopyError.Create (TryFormat(rsErrSetAttr,[destfilename]),ec);
        end
      else
        raise ECopyError.Create (TryFormat(rsErrTimeStamp,[destfilename]),ec);
    finally
      FreeMem(Buffer,BlockSize);
      end;
    end
  else raise ECopyError.Create (TryFormat(rsErrNotFound,[srcfilename]),ERROR_FILE_NOT_FOUND);
  end;

{ ---------------------------------------------------------------- }
// Copy files from one directory to another
function CopyFiles (const FromDir,ToDir,AMask : string; OverWrite : boolean) : boolean;
var
  DirInfo    : TSearchRec;
  Findresult : integer;
begin
  Result:=true;
  FindResult:=FindFirst(FromDir+AMask,faAllFiles,DirInfo);
  while (FindResult=0) and Result do with DirInfo do begin
    if OverWrite or not FileExists(ToDir+Name) then begin
      try
        CopyFileTS(FromDir+Name,ToDir+Name);
      except
        Result:=false
        end;
      end;
    FindResult:=FindNext(DirInfo)
    end;
  FindClose(DirInfo);
  end;

{ ---------------------------------------------------------------- }
// Copy file permissions (ACL)
function CopyFileAcl (const SrcFilename,DestFilename : string) : cardinal;
var
  SidOwner : PSID;
  SidGroup : PSID;
  DAcl     : PACL;
  SAcl     : PACL;
  sd       : PSecurityDescriptor;
  si       : SECURITY_INFORMATION;
begin
  sd:=nil;
  si:=DACL_SECURITY_INFORMATION;
  try
    Result:=GetNamedSecurityInfo (PChar(srcfilename),SE_FILE_OBJECT,si,
                    @SidOwner,@SidGroup,@DAcl,@SAcl,Pointer(sd));
    if Result=NO_ERROR then begin
      Result:=SetNamedSecurityInfo (PChar(destfilename),SE_FILE_OBJECT,si,
                    SidOwner,SidGroup,DAcl,SAcl);
      end;
  finally
    if sd<>nil then LocalFree(cardinal(sd));
    end;
  end;

{ ---------------------------------------------------------------- }
// Copy alternate file streams
function CopyAlternateStreams (const SrcFilename,DestFilename : string): cardinal;
var
  fsd : TWin32FindStream;
  sn  : string;
  n   : integer;
begin
  Result:=FileFindFirstStream(SrcFilename,fsd); // default data stream
  if Result=S_OK then begin
    repeat
      Result:=FileFindNextStream(fsd);   // find first alternate stream
      if Result=S_OK then begin
        n:=pos('$',fsd.Name);
        if n>0 then begin
          sn:=AnsiDequotedStr(copy(fsd.Name,1,pred(n)),':');
          if length(sn)>0 then Result:=CopyFileData(SrcFilename+':'+sn,DestFilename+':'+sn);
          end;
        end;
      until Result<>S_OK;
    if Result=ERROR_HANDLE_EOF then Result:=S_OK;
    Winapi.Windows.FindClose(fsd.FindHandle);
    end
  end;

{ ---------------------------------------------------------------- }
// Copy file attributes and timestamps
function CopyAttrAndTimestamp (const SrcFilename,DestFilename : string) : cardinal;
var
  SearchRec : TSearchRec;
  Handle    : THandle;
begin
  Result:=FindFirst(SrcFilename,faAnyFile,SearchRec);
  if Result=S_OK  then begin
    Result:=FileSetAttr(DestFilename,SearchRec.Attr,false);
    if Result=S_OK then begin
      Handle:=CreateFile(PChar(DestFilename),FILE_WRITE_ATTRIBUTES,0,nil,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,0);
      if Handle=INVALID_HANDLE_VALUE  then Result:=GetLastError
      else with SearchRec.FindData do begin
        if not SetFileTime(Handle,@ftCreationTime,@ftLastAccessTime,@ftLastWriteTime) then
          Result:=GetLastError;
        FileClose(Handle);
        end;
      end;
    end
  end;

{ ---------------------------------------------------------------- }
// convert file attribute to string
function FileAttrToString(Attr : word) : string;
var
  s : string;
begin
  s:='';
  if Attr and faReadOnly =0 then s:=s+'-' else s:=s+'r';
  if Attr and faArchive =0 then s:=s+'-' else s:=s+'a';
  if Attr and faHidden =0 then s:=s+'-' else s:=s+'h';
  if Attr and faSysFile =0 then s:=s+'-' else s:=s+'s';
//  if Attr and faNormal =0 then s:=s+'-' else s:=s+'n';
  if Attr and faSymLink	<>0 then s:=s+'L';
  Result:=s;
  end;

{ ---------------------------------------------------------------- }
// Clear = true  : clear given attributes
//       = false : set given attributes
function FileChangeAttr (const FileName: string; Attr: cardinal; Clear : boolean;
                         FollowLink: Boolean = True) : Integer;
var
  ao,an : cardinal;
begin
  Result:=NO_ERROR;
  ao:=FileGetAttr(FileName,FollowLink);
  if ao=INVALID_FILE_ATTRIBUTES then begin
    Result:=ERROR_FILE_NOT_FOUND;
    Exit;   // file does not exist
    end;
  if Clear then an:=ao and not Attr else an:=ao or Attr;
  if ao<>an then Result:=FileSetAttr(FileName,an,FollowLink);
  end;

{ ---------------------------------------------------------------- }
function GetFileSize (const FileData: TWin32FindData) : int64;  // required in Delphi 7
begin
  with TInt64(Result) do begin
    Lo:=FileData.nFileSizeLow; Hi:=FileData.nFileSizeHigh;
    end;
  end;

function GetFileSize (const FileData: TWin32FileAttributeData) : int64;
begin
  with TInt64(Result) do begin
    Lo:=FileData.nFileSizeLow; Hi:=FileData.nFileSizeHigh;
    end;
  end;

function LongFileSize (const FileName : string) : int64;
var
  FileData : TWin32FileAttributeData;
begin
  if GetFileAttrData(FileName,FileData)=ERROR_SUCCESS then Result:=GetFileSize(FileData)
  else Result:=0;
  end;

const
  SeekStep = $80000000;

{ ------------------------------------------------------------------- }
// Convert SearchRec to FileInfo
function SearchRecToFileInfo (SearchRec : TSearchRec) : TFileInfo;
begin
  with Result do begin
    Name:=SearchRec.Name;
    Attr:=SearchRec.Attr;
    Size:=SearchRec.Size;
    CreationTime:=FileTimeToLocalDateTime(SearchRec.FindData.ftCreationTime);
    DateTime:=SearchRec.TimeStamp;
    FileTime:=SearchRec.FindData.ftLastWriteTime;
    Res:=SearchRec.FindData.dwReserved0;
    end;
  end;

{ ------------------------------------------------------------------- }
// Get the path the link is pointing to
function GetLinkPath (const FileName: string) : string;
begin
  if not GetFileNameFromSymLink(FileName,Result) then Result:='';
  end;

// get the type of the reparse point (junction or symbolic)
// fr = IO_REPARSE_TAG_MOUNT_POINT    mklink /j ..
//    = IO_REPARSE_TAG_SYMLINK        mklink /d ..
function GetReparsePointType(const FileName : string) : TReparseType;
var
  fs : int64;
  ft : TFileTime;
  fa,fr : cardinal;
begin
  if GetFileInfo(FileName,fs,ft,fa,fr,true) then begin
    if fr=IO_REPARSE_TAG_MOUNT_POINT then Result:=rtJunction
    else if fr=IO_REPARSE_TAG_SYMLINK then Result:=rtSymbolic
    else Result:=rtNone;
    end
  else Result:=rtNone;
  end;

// Check if reparse point and return linked path if not recursive
function CheckForReparsePoint (const Path : string; Attr : integer;
                               var LinkPath : string; var RpType : TReparseType) : boolean;
begin
  Result:=false; LinkPath:=''; RpType:=rtNone;
  if Attr=-1 then Exit;
  if (Attr and FILE_ATTRIBUTE_REPARSE_POINT <>0) then begin  //directory entry is a reparse point
    RpType:=GetReparsePointType(ExcludeTrailingPathDelimiter(Path));
    LinkPath:=GetLinkPath(ExcludeTrailingPathDelimiter(Path));
    Result:=RpType<>rtNone;
    end;
  end;

function CheckForReparsePoint (const Path : string; Attr : integer;
                               var LinkPath : string) : boolean;
var
  RpType : TReparseType;
begin
  Result:=CheckForReparsePoint(Path,Attr,LinkPath,RpType);
  end;

// Check for reparse point
function IsReparsePoint (Attr : integer) : boolean;
begin
  Result:=false;
  if Attr=-1 then Exit;
  Result:=Attr and FILE_ATTRIBUTE_REPARSE_POINT <>0;  //directory entry is a reparse point
  end;

function IsReparsePoint (const Path : string) : boolean;
begin
  Result:=IsReparsePoint (FileGetAttr(Path,false));
  end;

{ ---------------------------------------------------------------- }
function GetJunction (const Path : string) : string;
var
  hDir   : THandle;
  n      : dword;
  rdb    : TReparseDataBuffer;
begin
  Result:='';
  if ModifyPrivilege(SE_BACKUP_NAME,true) then begin
    hDir:=CreateFile(PChar(Path),GENERIC_READ,0,nil,
                     OPEN_EXISTING,FILE_FLAG_OPEN_REPARSE_POINT or FILE_FLAG_BACKUP_SEMANTICS,0);
    if hDir<>INVALID_HANDLE_VALUE then begin
      if DeviceIoControl(hDir,FSCTL_GET_REPARSE_POINT,nil,0,@rdb,sizeof(rdb),n,nil) then begin
        with rdb do if ReparseTag=IO_REPARSE_TAG_MOUNT_POINT then begin
          Result:=copy(PathBuffer,SubstituteNameOffset,SubstituteNameLength);
          if AnsiStartsText('\??\',Result) then Delete(Result,1,4);
          end;
        end
      else n:=GetLastError;
      CloseHandle(hDir);
      end;
    end;
  end;

function CreateJunction(const Source,Destination : string): integer;
var
  hDir,
  hToken : THandle;
  tkp    : TTokenPrivileges;
  rdb    : TReparseDataBuffer;
  dest   : string;
  nl,n   : dword;
begin
  Result:=NO_ERROR;
  if DirectoryExists(Source) then begin
    if not IsEmptyDir(Source) then Result:=ERROR_DIR_NOT_EMPTY;
    end
  else if not ForceDirectories(Source) then Result:=GetLastError;
  if Result=NO_ERROR then begin
    // For some reason the destination string must be prefixed with \??\ otherwise
    // the IOCTL will fail, ensure it's there.
    if AnsiStartsText('\??\',Destination) then dest:=Destination
    else begin
      // Make sure Destination is a directory or again, the IOCTL will fail.
      Dest:=ExpandFileName(Destination);
      if (length(Dest)=0) or not DirectoryExists(Dest) then Exit;
      Dest:='\??\'+Dest;
      end;
    // Get a token for this process.
    if OpenProcessToken(GetCurrentProcess,TOKEN_ADJUST_PRIVILEGES,hToken) then begin
    // Get the LUID for the backup privilege.
      LookupPrivilegeValue(nil,SE_RESTORE_NAME,tkp.Privileges[0].Luid);
      tkp.PrivilegeCount:=1;  // one privilege to set
      tkp.Privileges[0].Attributes:=SE_PRIVILEGE_ENABLED;
    // Get the backup privilege for this process.
      AdjustTokenPrivileges(hToken,FALSE,tkp,0,nil,n);
      CloseHandle(hToken);
      nl:=length(Dest)*SizeOf(WideChar);
      FillChar(rdb,sizeof(TReparseDataBuffer),0);
      with rdb do begin
        ReparseTag:=IO_REPARSE_TAG_MOUNT_POINT;
        ReparseDataLength:=nl+12;
        SubstituteNameLength:=nl;
        PrintNameOffset:=nl+2;
        Move(Dest[1],PathBuffer,nl);
        end;
      hDir:=CreateFile(PChar(Source),GENERIC_READ or GENERIC_WRITE,0,nil,
                       OPEN_EXISTING,FILE_FLAG_OPEN_REPARSE_POINT or FILE_FLAG_BACKUP_SEMANTICS,0);
      if hDir<>INVALID_HANDLE_VALUE then begin
        try
          n:=0;
          if not DeviceIoControl(hDir,FSCTL_SET_REPARSE_POINT,@rdb,
            rdb.ReparseDataLength+REPARSE_DATA_BUFFER_HEADER_SIZE,nil,0,n,nil) then Result:=GetLastError;
        finally
          CloseHandle(hDir);
          end;
        end
      else Result:=GetLastError;
      end
    else Result:=GetLastError;
    end
  end;

{ ------------------------------------------------------------------- }
// Check if file is read-only
function IsFileReadOnly (const fName : string) : boolean;
var
  n : integer;
begin
  n:=FileGetAttr(fName);
  Result:=(n<>faInvalid) and ((n and faReadOnly)<>0);
  end;

// Check if file is in use
function IsFileInUse (const fName : string) : boolean;
var
  Handle : THandle;
begin
  Handle:=CreateFile(pchar(fName),GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
  Result:=Handle=INVALID_HANDLE_VALUE;
  if not Result then CloseHandle(Handle);
  end;

{ ------------------------------------------------------------------- }
// Check if path is a directory
function IsDirectory (const APath : string) : boolean;
var
  attr : cardinal;
begin
  attr:=FileGetAttr(APath,false);
  if attr=INVALID_FILE_ATTRIBUTES then Result:=false // not found
  else Result:=attr and faDirectory <>0;
  end;

{ ------------------------------------------------------------------- }
// Check if directory is empty
function IsEmptyDir (const Directory : string) : boolean;
var
  DirInfo    : TSearchRec;
  FindResult,
  n          : integer;
begin
  n:=0;
  FindResult:=FindFirst(SetDirName(Directory)+'*.*',faAnyFile,DirInfo);
  while (n=0) and (FindResult=0) do with DirInfo do begin
    if NotSpecialDir(Name) then inc(n);
    FindResult:=FindNext (DirInfo);
    end;
  FindClose(DirInfo);
  Result:=n=0;
  end;

{ ------------------------------------------------------------------- }
// Check if directory has subdirectories
function HasNoSubDirs (const Directory : string) : boolean;
var
  DirInfo    : TSearchRec;
  FindResult,
  n          : integer;
begin
  n:=0;
  FindResult:=FindFirst(SetDirName(Directory)+'*.*',faAnyFile,DirInfo);
  while (n=0) and (FindResult=0) do with DirInfo do begin
    if (Attr and faDirectory <>0) and NotSpecialDir(Name) then inc(n);
    FindResult:=FindNext (DirInfo);
    end;
  FindClose(DirInfo);
  Result:=n=0;
  end;

{ ---------------------------------------------------------------- }
// Delete empty directories
procedure DeleteEmptyDirectories (const Directory : string);
var
  DirInfo    : TSearchRec;
  FindResult : integer;
  s          : string;
begin
  FindResult:=FindFirst(SetDirName(Directory)+'*.*',faDirectory,DirInfo);
  while (FindResult=0) do with DirInfo do begin
    if NotSpecialDir(Name) then begin
      s:=SetDirName(Directory)+Name;
      DeleteEmptyDirectories(s);
      RemoveDir(s);
      end;
    FindResult:=FindNext (DirInfo);
    end;
  FindClose(DirInfo);
  end;

{ ------------------------------------------------------------------- }
// Check if directory holds a specified file type
function HasFileType (const Directory,Ext : string) : boolean;
var
  DirInfo    : TSearchRec;
begin
  Result:=FindFirst(ExpandToPath(Directory,'*',Ext),faAnyFile,DirInfo)=0;
  FindClose(DirInfo);
  end;

{ ---------------------------------------------------------------- }
// Count files in directory and calculate the resulting volume
procedure CountFiles (const Base,Dir,Ext : string; IncludeSubDir : boolean;
                      var FileCount : integer; var FileSize : int64);
var
  DirInfo    : TSearchRec;
  Findresult : integer;
  sd,se      : string;
begin
  sd:=SetDirName(SetDirName(Base)+Dir);
  FindResult:=FindFirst(sd+'*.*',faAnyFile,DirInfo);
  while FindResult=0 do with DirInfo do begin
    if IncludeSubDir and NotSpecialDir(Name) and ((Attr and faDirectory)<>0) then
      CountFiles (Base,SetDirName(Dir)+DirInfo.Name,Ext,IncludeSubDir,FileCount,FileSize);
    FindResult:=FindNext(DirInfo);
    end;
  FindClose(DirInfo);
  if length(Ext)=0 then se:='*' else se:=Ext;
  FindResult:=FindFirst(ExpandToPath(sd,'*',se),faAllFiles,DirInfo);
  while FindResult=0 do with DirInfo do begin
    if NotSpecialDir(Name) then begin
      inc(FileCount); inc(FileSize,Size);
      end;
    FindResult:=FindNext(DirInfo);
    end;
  FindClose(DirInfo);
  end;

procedure CountFiles (const Base,Dir : string; IncludeSubDir : boolean;
                      var FileCount : integer; var FileSize : int64);
begin
  CountFiles(Base,Dir,'',IncludeSubDir,FileCount,FileSize);
  end;

function DirFiles (const Directory : string; IncludeSubDir : boolean; Ext : string = '') : integer;
var
  n : int64;
begin
  Result:=0; n:=0;
  CountFiles(Directory,'',Ext,IncludeSubDir,Result,n);
  end;

function DirSize (const Directory : string; IncludeSubDir : boolean; Ext : string = '') : int64;
var
  n : integer;
begin
  Result:=0; n:=0;
  CountFiles(Directory,'',Ext,IncludeSubDir,n,Result);
  end;

// Delete a directory including all subdirectories and files
procedure DeleteDirectory (const Base,Dir           : string;
                           DeleteRoot               : boolean;
                           var DCount,FCount,ECount : cardinal);
// DCount: number of deleted directories
// FCount: number of deleted files
// ECount: number of errors
var
  DirInfo    : TSearchRec;
  fc,dc,
  Findresult : integer;
  s,sd       : string;
begin
  if length(Dir)>0 then sd:=SetDirName(Base)+Dir else sd:=Base;
  if DirectoryExists(sd) then begin
    FindResult:=FindFirst(SetDirName(sd)+'*.*',faAnyFile,DirInfo);
    while FindResult=0 do with DirInfo do begin
      if NotSpecialDir(Name) and ((Attr and faDirectory)<>0) then
        DeleteDirectory(Base,SetDirName(Dir)+DirInfo.Name,DeleteRoot,DCount,FCount,ECount);
      FindResult:=FindNext(DirInfo);
      end;
    FindClose(DirInfo);
    fc:=0; dc:=0;
    FindResult:=FindFirst(SetDirName(sd)+'*.*',faAllFiles,DirInfo);
    while FindResult=0 do with DirInfo do begin
      if NotSpecialDir(Name) then begin
        inc(fc);
        (* Dateien l�schen *)
        s:=SetDirName(sd)+Name;
        FileSetAttr(s,faArchive);
        if DeleteFile(s) then begin
          inc(FCount); inc(dc);
          end
        else inc(ECount);  // Fehler
        end;
      FindResult:=FindNext(DirInfo);
      end;
    FindClose(DirInfo);
    if (fc=dc) and (DeleteRoot or (length(Dir)>0)) then begin   // Verzeichnis leer ==> l�schen
      FileSetAttr(sd,0);    // Attribute zum L�schen entfernen
      if RemoveDir(sd) then inc(DCount) else inc(ECount);
      end;
    end;
  end;

function DeleteDirectory (const Directory : string;
                          DeleteRoot      : boolean) : boolean;
var
  fc,dc,ec : cardinal;
begin
  fc:=0; dc:=0; ec:=0;
  DeleteDirectory(Directory,'',DeleteRoot,dc,fc,ec);
  Result:=ec=0;
  end;

{ ---------------------------------------------------------------- }
// Check if a directory is accessible
function CanAccess (const Directory : string; var ErrorCode : integer) : boolean;
var
  fd : TSearchRec;
begin
  if not DirectoryExists(Directory) then ErrorCode:=ERROR_PATH_NOT_FOUND
  else begin
    ErrorCode:=FindFirst(SetDirName(Directory)+'*.*',faAnyFile,fd);
    FindClose(fd);
    end;
  Result:=(ErrorCode=0) or (Error=ERROR_NO_MORE_FILES);
  end;

function CanAccess (const Directory : string) : boolean; overload;
var
  ec : integer;
begin
  Result:=CanAccess(Directory,ec);
  end;

function FileNotFound (const FileName : string) : boolean;
var
//  SearchRec: TSearchRec;
  LastError : Cardinal;
begin
//  Result:=FindFirst(FileName,faAnyFile,SearchRec)=ERROR_FILE_NOT_FOUND;
  Result:=GetFileAttributes(PChar(FileName))=INVALID_FILE_ATTRIBUTES;
  if Result then begin
    LastError:=GetLastError;
    Result:=(LastError=ERROR_FILE_NOT_FOUND) or (LastError=ERROR_PATH_NOT_FOUND)
    or (LastError=ERROR_INVALID_NAME);
    end;
  end;

// -----------------------------------------------------------------------------
// Reset timestamps and file data
procedure TFileTimestamps.Reset;
begin
  Valid:=false;
  CreationTime:=ResetFileTime;
  LastWriteTime:=ResetFileTime;
  LastAccessTime:=ResetFileTime;
  end;

procedure TFileTimestamps.SetTimeStamps(CTime, MTime: TDateTime);
begin
  Valid:=True;
  CreationTime:=LocalDateTimeToFileTime(CTime);
  LastWriteTime:=LocalDateTimeToFileTime(MTime);
  LastAccessTime:=LastWriteTime;
  end;

{ ------------------------------------------------------------------- }
{$IFDEF Trace}
var
  fDebug : TextFile;
  DebugOn : boolean = false;

procedure OpenDebugLog (Filename : string);
begin
  Filename:=SetDirName(TempDirectory)+Filename;
  AssignFile(fDebug,Filename);
  if FileExists(Filename) then begin
    {$I-} Append (fDebug) {$I+};
    end
  else {$I-} Rewrite(fDebug) {$I+};
  DebugOn:=IoResult=0;
  if DebugOn then begin
    Writeln(fDebug,'************************************');
    Writeln(fDebug,'Trace started at '+DateTimeToStr(Now));
    Flush(fDebug);
    end;
  end;

procedure CloseDebugLog;
begin
  if DebugOn then begin
    Writeln(fDebug,'Trace ended at '+DateTimeToStr(Now));
    CloseFile(fDebug);
    end;
  end;

procedure WriteDebugLog (const DebugText: string);
begin
  if DebugOn then begin
    Writeln(fDebug,FormatDateTime(' hh:nn:ss.zzz',Now)+': '+DebugText);
    Flush(fDebug);
    end;
  end;
{$ENDIF}

end.
