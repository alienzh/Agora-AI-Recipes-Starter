import { Transcript, TranscriptType } from '../../convoaiApi/IConversationalAIAPI';

/**
 * Basic data source for LazyForEach
 * Reference: HarmonyOS BestPracticeSnippets BasicDataSource pattern
 */
class BasicDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  protected originDataArray: Transcript[] = [];

  totalCount(): number {
    return 0;
  }

  getData(index: number): Transcript {
    return this.originDataArray[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
      const timestamp = Date.now();
      console.info('TranscriptDataSource', `[Thread] registerDataChangeListener, total listeners:${this.listeners.length}, timestamp:${timestamp}`);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
      const timestamp = Date.now();
      console.info('TranscriptDataSource', `[Thread] unregisterDataChangeListener, remaining listeners:${this.listeners.length}, timestamp:${timestamp}`);
    }
  }

  /**
   * Notify data reloaded
   */
  protected notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  /**
   * Notify data added at index
   */
  protected notifyDataAdd(index: number): void {
    const timestamp = Date.now();
    console.info('TranscriptDataSource', `[Thread] notifyDataAdd index:${index}, listeners:${this.listeners.length}, timestamp:${timestamp}`);
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  /**
   * Notify data changed at index
   */
  protected notifyDataChange(index: number): void {
    const timestamp = Date.now();
    console.info('TranscriptDataSource', `[Thread] notifyDataChange index:${index}, listeners:${this.listeners.length}, timestamp:${timestamp}`);
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  /**
   * Notify data deleted at index
   */
  protected notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }

  /**
   * Notify data moved
   */
  protected notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    });
  }
}

/**
 * Transcript data source extends BasicDataSource
 * Manages transcript data and notifies UI changes
 */
export class TranscriptDataSource extends BasicDataSource {
  private dataArray: Transcript[] = [];

  totalCount(): number {
    return this.dataArray.length;
  }

  getData(index: number): Transcript {
    return this.dataArray[index];
  }

  /**
   * Find index by turnId and type
   */
  findIndex(turnId: number, type: TranscriptType): number {
    return this.dataArray.findIndex(t => t.turnId === turnId && t.type === type);
  }

  /**
   * Add data at specific index
   */
  addData(index: number, data: Transcript): void {
    this.dataArray.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  /**
   * Push data to the end
   */
  pushData(data: Transcript): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  /**
   * Update data at specific index
   * Only notify if data actually changed
   * Create new object reference to ensure UI reactivity
   */
  updateDataAt(index: number, data: Transcript): void {
    if (index >= 0 && index < this.dataArray.length) {
      const oldData = this.dataArray[index];
      // Check if data actually changed
      const textChanged = oldData.text?.toString() !== data.text?.toString();
      const statusChanged = oldData.status !== data.status;
      const typeChanged = oldData.type !== data.type;
      
      if (textChanged || statusChanged || typeChanged) {
        // Create new object reference to ensure UI reactivity
        // ArkTS needs new object reference to detect changes
        const newTranscript: Transcript = {
          turnId: data.turnId,
          userId: data.userId,
          text: data.text,
          status: data.status,
          type: data.type,
        };
        this.dataArray[index] = newTranscript;
        this.notifyDataChange(index);
      } else {
        // Data unchanged, skip notification to avoid unnecessary UI updates
        console.info('TranscriptDataSource', `[Thread] Data unchanged at index:${index}, skipping update`);
      }
    }
  }

  /**
   * Update or add data by turnId and type
   */
  addOrUpdateData(data: Transcript): void {
    const timestamp = Date.now();
    console.info('TranscriptDataSource', `[Thread] addOrUpdateData called, turnId:${data.turnId}, type:${data.type}, timestamp:${timestamp}`);
    
    const index = this.findIndex(data.turnId, data.type);
    if (index >= 0) {
      console.info('TranscriptDataSource', `[Thread] Updating at index:${index}, timestamp:${timestamp}`);
      this.updateDataAt(index, data);
    } else {
      console.info('TranscriptDataSource', `[Thread] Pushing new data, timestamp:${timestamp}`);
      this.pushData(data);
    }
  }

  /**
   * Clear all data
   */
  clearData(): void {
    this.dataArray = [];
    this.notifyDataReload();
  }
}

