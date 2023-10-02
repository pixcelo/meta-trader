class PrintManager
{
private:
    bool isLoggingEnabled;
    string names[];
    int counts[];

public:
    PrintManager() {
        isLoggingEnabled = true; // default
    }

    void EnableLogging(bool enable) {
        isLoggingEnabled = enable;
    }

    void PrintLog(string msg) {
        if(isLoggingEnabled) {
            Print(msg);
        }
    }

    void Count(string name) {
        int index = ArraySearch(names, name);
        if(index == -1) {
            ArrayResize(names, ArraySize(names)+1);
            ArrayResize(counts, ArraySize(counts)+1);
            names[ArraySize(names)-1] = name;
            counts[ArraySize(counts)-1] = 1;
        } else {
            counts[index]++;
        }
    }

    void ShowCounts() {
        for(int i=0; i<ArraySize(names); i++) {
            Print("Name: ", names[i], " Count: ", counts[i]);
        }
    }

    int ArraySearch(string &arr[], string value) {
        for(int i=0; i<ArraySize(arr); i++) {
            if(arr[i] == value) return i;
        }
        return -1;
    }
};
