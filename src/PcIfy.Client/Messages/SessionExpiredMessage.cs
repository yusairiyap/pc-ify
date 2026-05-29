using CommunityToolkit.Mvvm.Messaging.Messages;

namespace PcIfy.Client.Messages;

public class SessionExpiredMessage : ValueChangedMessage<string>
{
    public SessionExpiredMessage() : base("Session expired. Please log in again.") { }
}
