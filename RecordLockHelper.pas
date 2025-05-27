unit uRecordLockHelper;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Data.Win.ADODB, XMLDoc, XMLIntf;

type
  TRecordLockHelper = class;
  TRecordLockHelperClass = class of TRecordLockHelper;

  // This is the base interface for record locking, defining the fundamental capability to check if record locking is enabled for an entity.
  IRecordLock = Interface
    ['{A81B193D-16F7-4EF1-BED4-FFE52B88C31F}']
    function GetRecordLockEnabled: Boolean;
    property RecordLockEnabled: Boolean read GetRecordLockEnabled;
  End;

  // This interface extends IRecordLock and introduces properties for more granular record locking.
  IRecordLockVS = Interface(IRecordLock)
    ['{D4442B6B-021F-4C78-9D2C-E8BADDDF2B11}']
    function GetRecordLockRequired: Boolean;
    function GetAllowLockTakeOver: Boolean;
    function GetReadTimeStamp: TDateTime;
    procedure SetReadTimeStamp(const Value: TDateTime);
    property RecordLockRequired: Boolean read GetRecordLockRequired;
    property AllowLockTakeOver: Boolean read GetAllowLockTakeOver;
    property ReadTimeStamp: TDateTime read GetReadTimeStamp write SetReadTimeStamp;
  End;

  // This interface specializes IRecordLockVS when data source is a TDataSet.
  IDataSetRecordLockVS = Interface(IRecordLockVS)
    ['{AD15B9D9-0019-4A48-89A0-E07F30384F07}']
    function AcquireLock(DataSet: TDataSet): Boolean;
  End;

  // This interface specializes IRecordLockVS when data source is an IXMLNode.
  IXMLRecordLockVS = Interface(IRecordLockVS)
    ['{C49D2DA9-0001-4A5D-BDBE-D825B059A6C1}']
    function AcquireLock(DataSet: IXMLNode): Boolean;
  End;

  // This is the interface for full back-end implementation of record locking and unlocking based on TDataSet.
  IRecordLockProc = Interface(IRecordLock)
    ['{05573B94-36FD-4CB2-8245-72365294EA23}']
    function AcquireLock(DataSet: TDataSet; const VirtualSet: string;
      AllowLockTakeOver: Boolean = False; ReadTimeStamp: TDateTime = 0;
      TimeoutOverride: Integer = 0): Boolean; overload;
    function AcquireLock(DataSet: TDataSet; const Entity, Field: string;
      AllowLockTakeOver: Boolean = False; ReadTimeStamp: TDateTime = 0;
      TimeoutOverride: Integer = 0): Boolean; overload;
    procedure ReleaseLock(DataSet: TDataSet; const VirtualSet: string); overload;
    procedure ReleaseLock(DataSet: TDataSet; const Entity, Field: string); overload;
  End;

  // Placeholder for potential future transactional record locking.
  ITransactionalRecordLock = Interface
    ['{E3BCA1C4-7EB6-4020-8C3D-61D06684F693}']
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
  End;

  TLockStatus = (lsNone, lsLocked, lsUnlocked);
  TLockUnlockOp = (opLock, opUnlock);

  // Structure defining the fields of the logical lock table in the database.
  TRecordLockTable = record
    TableName: String;
    TableID: String;
    Entity: String;
    Record_ID: String;
    Session: String;
    Username: String;
    Time: String;
    Expiration: String;
  end;

  // Structure to hold processed record IDs for locking/unlocking.
  TRecordIDs = record
    IDs: WideString;
    Values: WideString;
    Count: integer;
  end;

  // Class to hold information about the lock status for a given record.
  TLockInfo = class(TObject)
  private
    FStatus: TLockStatus;
    FTime: TDateTime;
    FExpiration: TDateTime;
    FLockedBy: String;
    function GetAcquired: Boolean;
    function GetXMLStatus: String; // Converts lock status to XML string.
  protected
    property Expiration: TDateTime read FExpiration write FExpiration;
    property Time: TDateTime read FTime write FTime;
    property XMLStatus: String read GetXMLStatus;
    property LockedBy: String read FLockedBy write FLockedBy;
  public
    constructor Create;
    property Acquired: Boolean read GetAcquired;
    property Status: TLockStatus read FStatus write FStatus;
  end;

  // Interface for loading record IDs from various sources.
  IRecordIDsLoader = Interface
    ['{7D706552-65CF-4AA7-9928-1C09413B21C7}']
    function Load(const Name: string): TRecordIDs;
  End;

  // Base class for record ID loaders, handles common ID processing.
  TRecordIDsLoaderBase = class(TInterfacedObject)
  private
    FIDs: TStringList;
    function GetIDs: WideString;
    function GetValues: WideString;
    function GetCount: integer;
  protected
    procedure Add(const ID: string); // Adds ID, ensuring no duplicates.
  public
    constructor Create;
    destructor Destroy; override;
    property Count: integer read GetCount;
    property IDs: WideString read GetIDs;
    property Values: WideString read GetValues;
  end;

  // Loader for record IDs from a TDataSet component.
  TRecordIDsLoaderDataSet = class(TRecordIDsLoaderBase, IRecordIDsLoader)
  private
    FDataSet: TDataSet;
  public
    constructor Create(DataSet: TDataSet);
    function Load(const Field: string): TRecordIDs;
  end;

  // Loader for record IDs from an IXMLNode (e.g., XML payload).
  TRecordIDsLoaderXMLNode = class(TRecordIDsLoaderBase, IRecordIDsLoader)
  private
    FDataSet: IXMLNode;
  public
    constructor Create(DataSet: IXMLNode);
    function Load(const Attribute: string): TRecordIDs;
  end;

  // Main helper class for logical record locking operations.
  TRecordLockHelper = class(TYourFrameworkBaseClass) 
  private
    FRecordLockTable: TRecordLockTable;
    FLockInfo: TLockInfo;
    FEntity: String;
    FField: String;
    FReadTimeStamp: TDateTime;
    FAllowLockTakeover: Boolean;
    FTimeoutOverride: integer;

    function GetRecordLockTable: TRecordLockTable;
  protected
    // Central method for locking/unlocking based on the operation and loaded IDs.
    procedure doLockUnlock(Loader: IRecordIDsLoader; op: TLockUnlockOp);
    procedure Lock(const RecordIDs: TRecordIDs); virtual;
    procedure Unlock(const RecordIDs: TRecordIDs); virtual;
    function GetTimeout: Integer; virtual; // Returns the lock timeout in minutes.
  public
    constructor Create(AOwner: TComponent; Session: TYourFrameworkSessionClass); overload; 
    destructor Destroy; override;

    // Methods to write lock/unlock operations based on different data sources.
    procedure WriteLockTable(DataSet: TDataSet; op: TLockUnlockOp); overload;
    procedure WriteLockTable(DataSet: IXMLNode; op: TLockUnlockOp); overload;
    
    // Methods to add lock status information to XML output or attributes.
    procedure AddOutput(Root: IXMLNode);
    procedure AddAttributes(Root: IXMLNode);

    // Class methods for managing RecordLockHelper instances and global operations.
    class procedure AddRecordLockAlias(rlClass: TRecordLockHelperClass; const rlAlias: string);
    class function GetClass(const ClassAlias: string): TRecordLockHelperClass;
    class function GetObject(const ClassAlias: string; AOwner: TComponent; Session: TYourFrameworkSessionClass): TRecordLockHelper;

    // Class procedure to optimize (clean up) the lock table.
    class procedure OptimizeLockTable(Session: TYourFrameworkSessionClass);
    // Class function to check if record locking is enabled for a session.
    class function RecordLockEnabled(Session: TYourFrameworkSessionClass): Boolean; virtual;
    // Class function to get the default field definitions for the lock table.
    class function GetTableDefinition: TRecordLockTable; virtual;

    property RecordLockTable: TRecordLockTable read GetRecordLockTable;
    property LockInfo: TLockInfo read FLockInfo;
    property Entity: string read FEntity write FEntity;
    property Field: string read FField write FField;
    property ReadTimeStamp: TDateTime read FReadTimeStamp write FReadTimeStamp;
    property AllowLockTakeover: Boolean read FAllowLockTakeover write FAllowLockTakeover;
    property TimeoutOverride: integer read FTimeoutOverride write FTimeoutOverride;
  end;

implementation

uses // Essential common units to compile the snippet (minimize for public release)
  System.SysUtils, System.Classes, Data.DB, Data.Win.ADODB, XMLDoc, XMLIntf,
  SyncObjs, StrUtils, DateUtils;

var
  rlLock: TCriticalSection; // For thread-safe access to internal lists (e.g., rlList)
  rlList: TStringList; // List for RecordLockHelper class aliases

const
  DefaultTimeout = 1; // Default lock timeout in minutes

// --- TLockInfo implementation (can be included as it's self-contained) ---
constructor TLockInfo.Create;
begin
  inherited Create;
  FStatus := lsNone;
  FTime := Now;
  FExpiration := FTime;
  FLockedBy := '';
end;

function TLockInfo.GetAcquired: Boolean;
begin
  Result := (FStatus = lsLocked);
end;

function TLockInfo.GetXMLStatus: String;
const
  LockStatusText: array[TLockStatus] of string = ('none', 'locked', 'unlocked'); // Text representation of lock status
begin
  Result := LockStatusText[FStatus];
end;

// --- TRecordIDsLoaderBase implementation ---
procedure TRecordIDsLoaderBase.Add(const ID: string);
begin
  if (FIDs.IndexOf(ID) < 0) then // Prevent duplicate IDs that could interfere with Count property
    FIDs.Add(ID);
end;

function TRecordIDsLoaderBase.GetCount: integer;
begin
  Result := FIDs.Count;
end;

constructor TRecordIDsLoaderBase.Create;
begin
  inherited Create;
  FIDs := TStringList.Create;
  FIDs.Delimiter := ',';
end;

destructor TRecordIDsLoaderBase.Destroy;
begin
  FreeAndNil(FIDs);
  inherited;
end;

function TRecordIDsLoaderBase.GetIDs: WideString;
begin
  Result := FIDs.CommaText;
end;

function TRecordIDsLoaderBase.GetValues: WideString;
var
  a: TArray<string>;
begin
  a := FIDs.ToStringArray;
  Result := '(' + String.Join('),(', a) + ')'; // Formats IDs for SQL VALUES clause
end;

// --- TRecordIDsLoaderDataSet implementation ---
constructor TRecordIDsLoaderDataSet.Create(DataSet: TDataSet);
begin
  inherited Create;
  FDataSet := DataSet;
end;

function TRecordIDsLoaderDataSet.Load(const Field: string): TRecordIDs;
var
  bm: TBookMark;
begin
  if (not Assigned(FDataSet.FindField(Field))) then
    raise Exception.Create('Cannot lock/unlock from dataset: field ' + Field + ' unknown. Check RecordLock constructor parameters.');

  // IMPORTANT: The dataset's navigation methods (like Next) can trigger events
  // that, within specific contexts (e.g., objects that handle data saving/loading), 
  // could lead to infinite loops.
  //
  // Therefore, to avoid these side effects and ensure stable operation when
  // dealing with such processors, we avoid direct iteration on the dataset if
  // RecordCount is 1. If there's only a single record, we process it directly.
  // For multiple records, we must manually iterate, saving and restoring
  // the bookmark to preserve the original dataset position.
  if (FDataSet.RecordCount = 1) then
    Self.Add(FDataSet.FieldByName(Field).AsString)
  else begin
    bm := FDataSet.GetBookmark; // Save current position
    FDataSet.First;
    while not FDataSet.Eof do begin
      Self.Add(FDataSet.FieldByName(Field).AsString);
      FDataSet.Next;
    end;
    FDataSet.GoToBookMark(bm); // Restore original position
  end;
  Result.IDs := Self.IDs;
  Result.Values := Self.Values;
  Result.Count := Self.Count;
end;

// --- TRecordIDsLoaderXMLNode implementation (include to show different input handling) ---
constructor TRecordIDsLoaderXMLNode.Create(DataSet: IXMLNode);
begin
  inherited Create;
  FDataSet := DataSet;
end;

function TRecordIDsLoaderXMLNode.Load(const Attribute: string): TRecordIDs;
var
  i: integer;
begin
  for i := 0 to FDataSet.ChildNodes.Count - 1 do begin
    var Node: IXMLNode := FDataSet.ChildNodes[i];
    Self.Add(Node.Attributes[Attribute]);
  end;
  Result.IDs := Self.IDs;
  Result.Values := Self.Values;
  Result.Count := Self.Count;
end;

// --- TRecordLockHelper implementation (core logic) ---

// Constructor and destructor minimal representation
constructor TRecordLockHelper.Create(AOwner: TComponent; Session: TYourFrameworkSessionClass);
var
  Def: String;
begin
  // Initialize FRecordLockTable using GetTableDefinition
  FRecordLockTable := GetTableDefinition;

  // Validate the definition of the lock table fields, ensuring no empty or invalid characters.
  Def := ',' +
    Trim(FRecordLockTable.TableName) + ',' +
    Trim(FRecordLockTable.TableID) + ',' +
    Trim(FRecordLockTable.Entity) + ',' +
    Trim(FRecordLockTable.Record_ID) + ',' +
    Trim(FRecordLockTable.Session) + ',' +
    Trim(FRecordLockTable.Username) + ',' +
    Trim(FRecordLockTable.Time) + ',' +
    Trim(FRecordLockTable.Expiration) + ',';

  if (Def.Contains('[')) or (Def.Contains(']')) then
    raise Exception.Create('Square brackets are not allowed in RecordLockTable definition properties.');

  if (Def.Contains(',,')) then
    raise Exception.Create('Cannot assign an empty value to RecordLockTable definition properties.');

  FLockInfo := TLockInfo.Create; // Initialize LockInfo object
  // [...] other initialization specific to YourFrameworkBaseClass
end;

destructor TRecordLockHelper.Destroy;
begin
  FreeAndNil(FLockInfo);
  inherited;
end;

// [...] Additional properties and methods not published.

// The main Lock procedure, showing the conditional acquisition and takeover logic.
procedure TRecordLockHelper.Lock(const RecordIDs: TRecordIDs);
var
  qry: TggWSQuery; // Assuming TggWSQuery is your custom query component
  SQL: TStringList;
  LockTable: TRecordLockTable;
  TransactionOwner: Boolean;
begin
  LockTable := FRecordLockTable;
  qry := TggWSQuery.Create(nil);
  qry.Connection := User.dbWRK; // Assuming User.dbWRK is the database connection object

  SQL := TStringList.Create;
  try
    TransactionOwner := (not qry.Connection.InTransaction);
    if (TransactionOwner) then
      qry.Connection.BeginTrans;

    // SQL MERGE statement for acquiring/updating locks.
    // This query reflects the core logic of lock acquisition and conditional takeover.
    SQL.Add('merge ' + LockTable.TableName + ' as dest ');
    SQL.Add('using (select * from (values' + RecordIDs.Values + ') SAMLAuthData(Record_ID)) as source on source.Record_ID = dest.' + LockTable.Record_ID);
    SQL.Add('when matched and (');
    SQL.Add('(isnull(dest.' + LockTable.TableID + ', 0) = 0) or '); // No existing lock or previous lock cleared
    SQL.Add('(dest.' + LockTable.Session + ' = @session)'); // Same session attempting to re-lock
    if (FAllowLockTakeover) then // Conditional takeover logic
      SQL.Add('or (dest.' + LockTable.Expiration + ' < @readtimestamp)'); // Takeover allowed if last lock expired before current read
    SQL.Add(')');
    SQL.Add('then update set ');
    SQL.Add('dest.' + LockTable.Session + ' = @session,');
    SQL.Add('dest.' + LockTable.Username + ' = @username,');
    SQL.Add('dest.' + LockTable.Time + ' = @time,');
    SQL.Add('dest.' + LockTable.Expiration + ' = @expiration');
    SQL.Add('when matched and not ('); // Condition for failing to acquire or update lock
    SQL.Add('(isnull(dest.' + LockTable.TableID + ', 0) = 0) or ');
    SQL.Add('(dest.' + LockTable.Session + ' = @session)');
    if (FAllowLockTakeover) then
      SQL.Add('or (dest.' + LockTable.Expiration + ' < @readtimestamp)');
    SQL.Add(') then raiserror(''Record locked by another user.'', 16, 1)'); // Raise error if lock cannot be acquired/updated
    SQL.Add('when not matched then insert(' + LockTable.Record_ID + ',' + LockTable.Session + ',' + LockTable.Username + ',' + LockTable.Time + ',' + LockTable.Expiration + ') ');
    SQL.Add('values(source.Record_ID, @session, @username, @time, @expiration);');
    SQL.Add('select LOCKS = count(*) from ' + LockTable.TableName + ' with (updlock, rowlock) where ' + LockTable.Session + ' = @session and ' + LockTable.Record_ID + ' in (' + RecordIDs.IDs + ');'); // Count acquired locks

    qry.SQL.Text := SQL.Text;
    qry.Parameters.ParamByName('SESSION').Value := User.GlobalSessionID; // Assuming User.GlobalSessionID is available
    qry.Parameters.ParamByName('USERNAME').Value := User.UserName; // Assuming User.UserName is available
    qry.Parameters.ParamByName('TIME').Value := Now;
    qry.Parameters.ParamByName('EXPIRATION').Value := IncMinute(Now, GetTimeout); // Lock expiration time
    qry.Parameters.ParamByName('READTIMESTAMP').Value := FReadTimeStamp; // Read timestamp for takeover logic

    qry.Open; // Execute query and retrieve results
    
    FLockInfo.Status := lsUnlocked; // Default to unlocked if not all locks are acquired
    FLockInfo.LockedBy := ''; // Clear locked by info

    if (qry.FieldByName('LOCKS').AsInteger = RecordIDs.Count) then
      FLockInfo.Status := lsLocked // All requested locks acquired
    else begin
      // If not all locks were acquired, attempt to retrieve who holds the lock
      // This is a simplified example; a real implementation might involve a separate query or error handling.
      // [...] (Logic to retrieve locked by info, potentially another query)
    end;

    if (TransactionOwner) then
      qry.Connection.CommitTrans; // Commit transaction if it was started by this method

  except
    on E: Exception do begin
      FLockInfo.Status := lsUnlocked;
      FLockInfo.LockedBy := '';
      // Specific error handling for "Record locked by another user."
      if (ContainsText(E.Message, 'Record locked by another user.')) then begin
        // Additional logic to determine who locked the record, if necessary
        // This is a placeholder for actual error extraction and user feedback.
        // [...] (Logic to extract locked_by from error message or perform separate query)
        FLockInfo.LockedBy := 'Another User'; // Placeholder
      end;
      if (TransactionOwner) and (qry.Connection.InTransaction) then
        qry.Connection.RollbackTrans; // Rollback transaction on error
      raise; // Re-raise the exception after handling
    end;
  finally
    SQL.Free;
    if (qry.Active) then
      qry.Close;
    FreeAndNil(qry);
  end;
end;

// The main Unlock procedure.
procedure TRecordLockHelper.Unlock(const RecordIDs: TRecordIDs);
var
  qry: TggWSQuery; // Assuming TggWSQuery is your custom query component
  LockTable: TRecordLockTable;
  TransactionOwner: Boolean;
begin
  LockTable := FRecordLockTable;
  qry := TggWSQuery.Create(nil);
  // Assuming User is accessible here
  qry.Connection := User.dbWRK;

  try
    TransactionOwner := (not qry.Connection.InTransaction);
    if (TransactionOwner) then
      qry.Connection.BeginTrans;

    // Update the lock entry, setting its expiration to now to effectively release it.
    // This allows for conditional takeover based on the ReadTimeStamp logic.
    qry.SQL.Add('update ' + LockTable.TableName + ' with (updlock, rowlock) set ');
    qry.SQL.Add(LockTable.Expiration + ' = @expiration');
    qry.SQL.Add('where');
    qry.SQL.Add(LockTable.Record_ID + ' in (' + RecordIDs.IDs + ')');
    qry.SQL.Add('and ' + LockTable.Session + ' = @session;'); // Only allow unlock by the current session

    qry.Parameters.ParamByName('SESSION').Value := User.GlobalSessionID;
    qry.Parameters.ParamByName('EXPIRATION').Value := Now;
    qry.ExecSQL;

    if (TransactionOwner) then
      qry.Connection.CommitTrans;
  except
    // What to do? Probably nothing - if unlock fails, the lock will eventually expire.
    // But rollback transaction if it was started by this method.
    if (TransactionOwner) and (qry.Connection.InTransaction) then
      qry.Connection.RollbackTrans;
    raise; // Re-raise the exception after handling
  finally
    if (qry.Active) then
      qry.Close;
    FreeAndNil(qry);
  end;
end;

// Helper to bridge different input loaders to the main lock/unlock logic.
procedure TRecordLockHelper.doLockUnlock(Loader: IRecordIDsLoader; op: TLockUnlockOp);
var
  RecordIDs: TRecordIDs;
begin
  RecordIDs := Loader.Load(FField); // Load record IDs from the specified source
  if (RecordIDs.Count > 0) then begin
    if (op = opLock) then
      Self.Lock(RecordIDs)
    else
      Self.Unlock(RecordIDs);
  end;
end;

// Provides the default lock timeout. Can be overridden for custom logic.
function TRecordLockHelper.GetTimeout: Integer;
begin
  Result := DefaultTimeout; // Default to 1 minute
  if (FTimeoutOverride > 0) then
    Result := FTimeoutOverride; // Use override if provided
end;

// Class method to get the default field definitions for the lock table.
class function TRecordLockHelper.GetTableDefinition: TRecordLockTable;
begin
  Result.TableName  := 'RECORD_LOCKS'; // Default lock table name
  Result.TableID    := 'RL_ID'; // Primary key field name
  Result.Session    := 'SESSION_ID'; // Session ID field name
  Result.Record_ID  := 'RECORD_ID'; // Locked record ID field name
  Result.Entity     := 'ENTITY'; // Entity type (e.g., 'Customer', 'Order')
  Result.Username   := 'USERNAME'; // User who acquired the lock
  Result.Time       := 'TIME'; // Time lock was acquired
  Result.Expiration := 'EXPIRATION'; // Lock expiration time
end;

// Class procedure to optimize (clean up) the lock table by deleting expired locks.
class procedure TRecordLockHelper.OptimizeLockTable(Session: TYourFrameworkSessionClass);
var
  LockTable: TRecordLockTable;
  Locks: TADOQuery; 
begin
  LockTable := TRecordLockHelper.GetTableDefinition;

  Locks := TADOQuery.Create(nil);
  // Assuming Session.dbWRK is the database connection
  Locks.Connection := Session.dbWRK; 

  try
    // WARNING:
    // The following SELECT statement may trigger a lock escalation if a large
    // number of logical lock records are to be deleted.
    // To minimize impact, consider running this procedure during off-peak hours.
    Locks.SQL.Add('declare @now datetime');
    Locks.SQL.Add('set @now = :now');

    // Select to check count of expired locks (optional, for logging/monitoring)
    Locks.SQL.Add('select count(*) from ' + LockTable.TableName + ' with (updlock, rowlock) where @now > dateadd(day, 1, ' + LockTable.Expiration + ')');

    // Delete expired logical locks and reorganize index for performance.
    // Operation protected by physical locks previously acquired on the Lock Table.
    Locks.SQL.Add('delete from ' + LockTable.TableName + ' where @now > dateadd(day, 1, ' + LockTable.Expiration + ');');
    Locks.SQL.Add('alter index all on ' + LockTable.TableName + ' reorganize;'); // SQL Server specific index reorganize

    Locks.Parameters.ParamByName('NOW').Value := Now;
    Locks.ExecSQL;
  finally
    if (Locks.Active) then
      Locks.Close;
    FreeAndNil(Locks);
  end;
end;

// --- Other TRecordLockHelper methods (class methods for factory pattern) ---
// These example methods show how lock info is surfaced or how the helper instances are managed.

class procedure TRecordLockHelper.AddRecordLockAlias(rlClass: TRecordLockHelperClass; const rlAlias: string);
begin
  rlLock.Acquire; // Acquire critical section for thread safety
  try
    if not Assigned(rlList) then
      rlList := TStringList.Create;
    rlList.AddObject(rlAlias, rlClass); // Store alias and class reference
  finally
    rlLock.Release;
  end;
end;

class function TRecordLockHelper.GetClass(const ClassAlias: string): TRecordLockHelperClass;
var
  idx: integer;
begin
  rlLock.Acquire;
  try
    Result := nil;
    if Assigned(rlList) then begin
      idx := rlList.IndexOf(ClassAlias);
      if (idx > -1) then
        Result := TRecordLockHelperClass(rlList.Objects[idx]);
    end;
  finally
    rlLock.Release;
  end;
end;

class function TRecordLockHelper.GetObject(const ClassAlias: string; AOwner: TComponent; Session: TYourFrameworkSessionClass): TRecordLockHelper;
var
  rlClass: TRecordLockHelperClass;
begin
  rlClass := GetClass(ClassAlias);
  if (not Assigned(rlClass)) then
    raise Exception.Create('RecordLockHelper alias ' + ClassAlias + ' not found.');
  Result := rlClass.Create(AOwner, Session);
end;

class function TRecordLockHelper.RecordLockEnabled(Session: TYourFrameworkSessionClass): Boolean;
begin
  // Placeholder for logic to determine if record locking is enabled for the session
  // This might involve checking configuration settings, user permissions, etc.
  Result := True; // Assume enabled for showcase
end;

initialization
  rlLock := TCriticalSection.Create; // Initialize critical section

finalization
  FreeAndNil(rlList); // Free list
  FreeAndNil(rlLock); // Free critical section

end.
