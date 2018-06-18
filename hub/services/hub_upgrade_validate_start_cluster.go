package services

import (
	"fmt"
	"os"

	"github.com/greenplum-db/gpupgrade/hub/upgradestatus"
	pb "github.com/greenplum-db/gpupgrade/idl"

	"github.com/greenplum-db/gp-common-go-libs/gplog"
	"golang.org/x/net/context"
)

func (h *Hub) UpgradeValidateStartCluster(ctx context.Context,
	in *pb.UpgradeValidateStartClusterRequest) (*pb.UpgradeValidateStartClusterReply, error) {
	gplog.Info("Started processing validate-start-cluster request")

	go h.startNewCluster(in.NewBinDir, in.NewDataDir)

	return &pb.UpgradeValidateStartClusterReply{}, nil
}

func (h *Hub) startNewCluster(newBinDir string, newDataDir string) {
	gplog.Debug(h.conf.StateDir)
	c := upgradestatus.NewChecklistManager(h.conf.StateDir)
	err := c.ResetStateDir(upgradestatus.VALIDATE_START_CLUSTER)
	if err != nil {
		gplog.Error("failed to reset the state dir for validate-start-cluster")

		return
	}

	err = c.MarkInProgress(upgradestatus.VALIDATE_START_CLUSTER)
	if err != nil {
		gplog.Error("failed to record in-progress for validate-start-cluster")

		return
	}

	_, err = h.clusterPair.OldCluster.ExecuteLocalCommand(fmt.Sprintf("PYTHONPATH=%s && %s/gpstart -a -d %s", os.Getenv("PYTHONPATH"), newBinDir, newDataDir))
	if err != nil {
		gplog.Error(err.Error())
		cmErr := c.MarkFailed(upgradestatus.VALIDATE_START_CLUSTER)
		if cmErr != nil {
			gplog.Error("failed to record failed for validate-start-cluster")
		}

		return
	}

	err = c.MarkComplete(upgradestatus.VALIDATE_START_CLUSTER)
	if err != nil {
		gplog.Error("failed to record completed for validate-start-cluster")
		return
	}

	return
}
