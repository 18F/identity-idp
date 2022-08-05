import * as React from 'react';

import { Button } from '@18f/identity-components';

interface BackLinkProps extends React.ComponentProps<typeof Button> {
    includeBorder?: boolean;
}

const BackButton: React.FunctionComponent<BackLinkProps> = ({ includeBorder = false, ...props }) => {
    const button = (
        <Button isUnstyled={true} {...props}>
            &#x2039; Back
        </Button>
    );
    if (includeBorder) {
        return (
            <div className="margin-top-5 padding-top-2 border-top border-primary-light">
                {button}
            </div>
        );
    } else {
        return button;
    }
}

export default BackButton;